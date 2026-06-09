import { ReactNode } from "react";
import { useActiveSchool } from "@/hooks/use-active-school";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Link } from "@tanstack/react-router";
import { Building2 } from "lucide-react";

export function RequireActiveSchool({ children }: { children: (schoolId: string) => ReactNode }) {
  const { schoolId } = useActiveSchool();
  if (!schoolId) {
    return (
      <Card>
        <CardContent className="py-12 text-center space-y-4">
          <Building2 className="h-10 w-10 mx-auto text-muted-foreground" />
          <div>
            <h3 className="font-semibold">Belum ada sekolah aktif</h3>
            <p className="text-sm text-muted-foreground">
              Pilih sekolah di header, atau buat yayasan & sekolah baru dulu.
            </p>
          </div>
          <Button asChild>
            <Link to="/setup">Mulai Setup Yayasan & Sekolah</Link>
          </Button>
        </CardContent>
      </Card>
    );
  }
  return <>{children(schoolId)}</>;
}
