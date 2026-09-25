import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

enum StatusKind {
  online,
  offline,
  active,
  grace,
  expired,
  pending,
  verified,
  rejected,
  completed,
  cancelled,
  delivered,
  inProgress,
  open,
  paused,
  paid,
}

/// Status pill: 24px, dot + label. Colours follow the status palette.
class StatusPill extends StatelessWidget {
  const StatusPill(this.kind, {super.key, this.label, this.large = false});

  final StatusKind kind;

  /// Overrides the default label ("Under review", "Free trial"…).
  final String? label;

  /// 32px variant for headers (driver "Online").
  final bool large;

  static String defaultLabel(StatusKind k) => switch (k) {
        StatusKind.online => 'Online',
        StatusKind.offline => 'Offline',
        StatusKind.active => 'Active',
        StatusKind.grace => 'Grace',
        StatusKind.expired => 'Expired',
        StatusKind.pending => 'Pending',
        StatusKind.verified => 'Verified',
        StatusKind.rejected => 'Rejected',
        StatusKind.completed => 'Completed',
        StatusKind.cancelled => 'Cancelled',
        StatusKind.delivered => 'Delivered',
        StatusKind.inProgress => 'In progress',
        StatusKind.open => 'Open',
        StatusKind.paused => 'Paused',
        StatusKind.paid => 'Paid',
      };

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color dot) = switch (kind) {
      StatusKind.online => (RidoColors.success, Colors.white, Colors.white),
      StatusKind.offline => (RidoColors.inputBg, RidoColors.navy700, RidoColors.navy500),
      StatusKind.active ||
      StatusKind.verified ||
      StatusKind.completed ||
      StatusKind.delivered ||
      StatusKind.paid =>
        (RidoColors.successTint, RidoColors.successText, RidoColors.success),
      StatusKind.grace ||
      StatusKind.pending ||
      StatusKind.inProgress ||
      StatusKind.paused =>
        (RidoColors.warningTint, RidoColors.warningText, RidoColors.warning),
      StatusKind.expired || StatusKind.rejected || StatusKind.cancelled => (
          RidoColors.errorTint,
          RidoColors.error,
          RidoColors.error
        ),
      StatusKind.open => (RidoColors.coral50, RidoColors.coral600, RidoColors.coral500),
    };
    final t = context.type;
    return Container(
      height: large ? 36 : 26,
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10),
      decoration: BoxDecoration(color: bg, borderRadius: RidoRadii.pillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: large ? 10 : 7, height: large ? 10 : 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          SizedBox(width: large ? 8 : 6),
          Text(
            label ?? defaultLabel(kind),
            style: (large ? t.bodySemibold : t.caption.copyWith(fontWeight: FontWeight.w600)).copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
