import type { VehicleKind } from "@/lib/types";

/** Marker colour per vehicle kind (legend on the Live page uses the same map). */
export const VEHICLE_COLORS: Record<VehicleKind, string> = {
  BIKE: "#D84315",
  AUTO: "#F59E0B",
  CAB: "#1E293B",
  GOODS_BIKE: "#16A34A",
  THREE_WHEELER: "#0EA5E9",
  MINI_TRUCK: "#7C3AED",
  PICKUP: "#DB2777",
  TRUCK: "#64748B",
};
