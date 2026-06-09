import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { getFinanceReport } from "@/lib/finance.functions";
import { RequireActiveSchool } from "@/components/require-active-school";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Loader2, Printer } from "lucide-react";
import { formatRupiah } from "@/lib/format";

export const Route = createFileRoute("/_authenticated/akuntansi/laporan")({
  head: () => ({ meta: [{ title: "Laporan Keuangan — SIMAT" }] }),
  component: () => <RequireActiveSchool>{(s) => <Page schoolId={s} />}</RequireActiveSchool>,
});

function Page({ schoolId }: { schoolId: string }) {
  const [from, setFrom] = useState(() => { const d = new Date(); d.setDate(1); return d.toISOString().slice(0, 10); });
  const [to, setTo] = useState(new Date().toISOString().slice(0, 10));
  const fetch = useServerFn(getFinanceReport);
  const q = useQuery({ queryKey: ["fin-report", schoolId, from, to], queryFn: () => fetch({ data: { school_id: schoolId, from, to } }) });
  const r = q.data;
  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between print:hidden">
        <div><h1 className="text-3xl font-bold tracking-tight">Laporan Keuangan</h1>
          <p className="text-muted-foreground">Ringkasan tagihan, pembayaran, kas, dan jurnal pada periode.</p></div>
        <Button onClick={() => window.print()} variant="outline"><Printer className="h-4 w-4 mr-2" />Cetak</Button>
      </div>
      <Card className="print:hidden">
        <CardContent className="pt-6 flex items-end gap-2 flex-wrap">
          <div><Label>Dari</Label><Input type="date" value={from} onChange={(e) => setFrom(e.target.value)} /></div>
          <div><Label>Sampai</Label><Input type="date" value={to} onChange={(e) => setTo(e.target.value)} /></div>
        </CardContent>
      </Card>

      <div className="print:block">
        <div className="hidden print:block mb-4">
          <h2 className="text-2xl font-bold">Laporan Keuangan</h2>
          <p className="text-sm">Periode: {from} s.d. {to}</p>
        </div>

        {q.isLoading || !r ? <Loader2 className="h-5 w-5 animate-spin" /> : (
          <div className="space-y-6">
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <Stat label="Total Tagihan" value={formatRupiah(r.summary.totalInvoiced)} hint={`${r.invoiceCount} tagihan`} />
              <Stat label="Telah Dibayar" value={formatRupiah(r.summary.totalPaidInvoices)} />
              <Stat label="Tunggakan" value={formatRupiah(r.summary.outstanding)} hint="Belum lunas" />
              <Stat label="Penerimaan Tunai" value={formatRupiah(r.summary.totalPayments)} hint={`${r.paymentCount} pembayaran`} />
              <Stat label="Kas Masuk" value={formatRupiah(r.summary.cashIn)} />
              <Stat label="Kas Keluar" value={formatRupiah(r.summary.cashOut)} />
              <Stat label="Arus Bersih" value={formatRupiah(r.summary.net)} hint={r.summary.net >= 0 ? "Surplus" : "Defisit"} />
            </div>

            <Card>
              <CardHeader><CardTitle>Buku Besar Ringkas</CardTitle></CardHeader>
              <CardContent>
                <Table>
                  <TableHeader><TableRow>
                    <TableHead className="w-24">Kode</TableHead><TableHead>Akun</TableHead>
                    <TableHead className="text-right">Debit</TableHead>
                    <TableHead className="text-right">Kredit</TableHead>
                    <TableHead className="text-right">Saldo</TableHead>
                  </TableRow></TableHeader>
                  <TableBody>
                    {r.ledger.length === 0 && <TableRow><TableCell colSpan={5} className="text-center text-muted-foreground py-6">Tidak ada jurnal pada periode.</TableCell></TableRow>}
                    {r.ledger.map((l) => (
                      <TableRow key={l.code}>
                        <TableCell className="font-mono">{l.code}</TableCell>
                        <TableCell>{l.name}</TableCell>
                        <TableCell className="text-right">{formatRupiah(l.debit)}</TableCell>
                        <TableCell className="text-right">{formatRupiah(l.credit)}</TableCell>
                        <TableCell className="text-right font-medium">{formatRupiah(l.debit - l.credit)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          </div>
        )}
      </div>
    </div>
  );
}

function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <Card>
      <CardContent className="pt-6">
        <div className="text-sm text-muted-foreground">{label}</div>
        <div className="text-2xl font-bold mt-1">{value}</div>
        {hint && <div className="text-xs text-muted-foreground mt-1">{hint}</div>}
      </CardContent>
    </Card>
  );
}
