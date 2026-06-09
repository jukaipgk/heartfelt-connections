import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { listCashAccounts, upsertCashAccount, listCashTransactions, createCashTransaction } from "@/lib/finance.functions";
import { RequireActiveSchool } from "@/components/require-active-school";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Plus, Loader2, ArrowDownLeft, ArrowUpRight } from "lucide-react";
import { toast } from "sonner";
import { formatRupiah } from "@/lib/format";

export const Route = createFileRoute("/_authenticated/keuangan/kas-bank")({
  head: () => ({ meta: [{ title: "Kas & Bank — SIMAT" }] }),
  component: () => <RequireActiveSchool>{(s) => <Page schoolId={s} />}</RequireActiveSchool>,
});

function Page({ schoolId }: { schoolId: string }) {
  return (
    <div className="space-y-6">
      <div><h1 className="text-3xl font-bold tracking-tight">Kas & Bank</h1>
        <p className="text-muted-foreground">Kelola akun kas/bank dan mutasi transaksi.</p></div>
      <Tabs defaultValue="accounts">
        <TabsList>
          <TabsTrigger value="accounts">Akun</TabsTrigger>
          <TabsTrigger value="transactions">Mutasi</TabsTrigger>
        </TabsList>
        <TabsContent value="accounts"><AccountsTab schoolId={schoolId} /></TabsContent>
        <TabsContent value="transactions"><TxTab schoolId={schoolId} /></TabsContent>
      </Tabs>
    </div>
  );
}

function AccountsTab({ schoolId }: { schoolId: string }) {
  const qc = useQueryClient();
  const fetch = useServerFn(listCashAccounts);
  const q = useQuery({ queryKey: ["cash-accounts", schoolId], queryFn: () => fetch({ data: { school_id: schoolId } }) });
  const upsert = useServerFn(upsertCashAccount);
  const [open, setOpen] = useState(false);
  const [name, setName] = useState(""); const [type, setType] = useState<"CASH"|"BANK">("CASH");
  const [bankName, setBankName] = useState(""); const [accNum, setAccNum] = useState(""); const [opening, setOpening] = useState(0);
  const m = useMutation({ mutationFn: () => upsert({ data: { school_id: schoolId, name, type, bank_name: bankName || null, account_number: accNum || null, opening_balance: opening }}),
    onSuccess: () => { toast.success("Akun tersimpan"); qc.invalidateQueries({ queryKey: ["cash-accounts"] }); setOpen(false); setName(""); setBankName(""); setAccNum(""); setOpening(0); }});
  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Akun Kas & Bank</CardTitle>
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild><Button><Plus className="h-4 w-4 mr-2" />Akun Baru</Button></DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>Akun Kas/Bank</DialogTitle></DialogHeader>
              <div className="grid gap-3">
                <div><Label>Nama</Label><Input value={name} onChange={(e) => setName(e.target.value)} /></div>
                <div><Label>Tipe</Label>
                  <Select value={type} onValueChange={(v: any) => setType(v)}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent><SelectItem value="CASH">Kas</SelectItem><SelectItem value="BANK">Bank</SelectItem></SelectContent>
                  </Select>
                </div>
                {type === "BANK" && (
                  <div className="grid grid-cols-2 gap-3">
                    <div><Label>Nama Bank</Label><Input value={bankName} onChange={(e) => setBankName(e.target.value)} /></div>
                    <div><Label>No. Rekening</Label><Input value={accNum} onChange={(e) => setAccNum(e.target.value)} /></div>
                  </div>
                )}
                <div><Label>Saldo Awal</Label><Input type="number" value={opening || ""} onChange={(e) => setOpening(Number(e.target.value))} /></div>
              </div>
              <DialogFooter><Button onClick={() => m.mutate()} disabled={!name}>Simpan</Button></DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader><TableRow><TableHead>Nama</TableHead><TableHead>Tipe</TableHead><TableHead>Detail</TableHead><TableHead className="text-right">Saldo</TableHead></TableRow></TableHeader>
          <TableBody>
            {(q.data ?? []).length === 0 && <TableRow><TableCell colSpan={4} className="text-center text-muted-foreground py-8">Belum ada akun.</TableCell></TableRow>}
            {(q.data ?? []).map((a: any) => (
              <TableRow key={a.id}>
                <TableCell>{a.name}</TableCell>
                <TableCell><Badge variant="outline">{a.type}</Badge></TableCell>
                <TableCell className="text-xs text-muted-foreground">{a.bank_name ? `${a.bank_name} ${a.account_number ?? ""}` : "—"}</TableCell>
                <TableCell className="text-right font-semibold">{formatRupiah(a.balance)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}

function TxTab({ schoolId }: { schoolId: string }) {
  const qc = useQueryClient();
  const fetch = useServerFn(listCashTransactions);
  const q = useQuery({ queryKey: ["cash-tx", schoolId], queryFn: () => fetch({ data: { school_id: schoolId } }) });
  const accountsFn = useServerFn(listCashAccounts);
  const accs = useQuery({ queryKey: ["cash-accounts", schoolId], queryFn: () => accountsFn({ data: { school_id: schoolId } }) });
  const create = useServerFn(createCashTransaction);
  const [open, setOpen] = useState(false);
  const [accountId, setAccountId] = useState("");
  const [kind, setKind] = useState<"IN"|"OUT">("OUT");
  const [amount, setAmount] = useState(0); const [desc, setDesc] = useState("");
  const [category, setCategory] = useState(""); const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const m = useMutation({ mutationFn: () => create({ data: { school_id: schoolId, cash_account_id: accountId, kind, amount, category: category || null, description: desc, occurred_at: date }}),
    onSuccess: () => { toast.success("Transaksi tercatat"); qc.invalidateQueries({ queryKey: ["cash-tx"] }); qc.invalidateQueries({ queryKey: ["cash-accounts"] }); setOpen(false); setAmount(0); setDesc(""); setCategory(""); },
    onError: (e: any) => toast.error(e.message) });
  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Mutasi Kas / Bank</CardTitle>
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild><Button><Plus className="h-4 w-4 mr-2" />Transaksi Manual</Button></DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>Catat Transaksi</DialogTitle></DialogHeader>
              <div className="grid gap-3">
                <div className="grid grid-cols-2 gap-3">
                  <div><Label>Akun</Label>
                    <Select value={accountId} onValueChange={setAccountId}>
                      <SelectTrigger><SelectValue placeholder="Pilih..." /></SelectTrigger>
                      <SelectContent>{(accs.data ?? []).map((a: any) => <SelectItem key={a.id} value={a.id}>{a.name}</SelectItem>)}</SelectContent>
                    </Select>
                  </div>
                  <div><Label>Jenis</Label>
                    <Select value={kind} onValueChange={(v: any) => setKind(v)}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent><SelectItem value="IN">Masuk</SelectItem><SelectItem value="OUT">Keluar</SelectItem></SelectContent>
                    </Select>
                  </div>
                  <div><Label>Nominal</Label><Input type="number" value={amount || ""} onChange={(e) => setAmount(Number(e.target.value))} /></div>
                  <div><Label>Tanggal</Label><Input type="date" value={date} onChange={(e) => setDate(e.target.value)} /></div>
                  <div className="col-span-2"><Label>Kategori</Label><Input value={category} onChange={(e) => setCategory(e.target.value)} placeholder="mis. Listrik, Donasi" /></div>
                  <div className="col-span-2"><Label>Deskripsi</Label><Input value={desc} onChange={(e) => setDesc(e.target.value)} /></div>
                </div>
              </div>
              <DialogFooter><Button onClick={() => m.mutate()} disabled={!accountId || !desc || amount <= 0 || m.isPending}>Simpan</Button></DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader><TableRow><TableHead>Tanggal</TableHead><TableHead>Akun</TableHead><TableHead>Kategori</TableHead><TableHead>Deskripsi</TableHead><TableHead className="text-right">Nominal</TableHead></TableRow></TableHeader>
          <TableBody>
            {(q.data ?? []).length === 0 && <TableRow><TableCell colSpan={5} className="text-center text-muted-foreground py-8">Belum ada mutasi.</TableCell></TableRow>}
            {(q.data ?? []).map((t: any) => (
              <TableRow key={t.id}>
                <TableCell>{t.occurred_at}</TableCell>
                <TableCell>{t.cash_accounts?.name ?? "—"}</TableCell>
                <TableCell><Badge variant="outline">{t.category ?? "—"}</Badge></TableCell>
                <TableCell>{t.description}</TableCell>
                <TableCell className={`text-right font-medium ${t.kind === "IN" ? "text-green-600" : "text-red-600"}`}>
                  <span className="inline-flex items-center gap-1">
                    {t.kind === "IN" ? <ArrowDownLeft className="h-3 w-3" /> : <ArrowUpRight className="h-3 w-3" />}
                    {formatRupiah(t.amount)}
                  </span>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
