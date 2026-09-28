import 'package:flutter/material.dart';

import '../../glove/glove_ble.dart';
import '../../glove/glove_session.dart';
import '../../theme/app_theme.dart';
import '../finger_bend.dart';
import 'brand.dart';

/// The glove status card on the dark hero (design: .hx-glove). Real status only (no battery:
/// the glove can't measure it). Replaces the old pairing screen: connect / disconnect from here.
class GloveCard extends StatelessWidget {
  const GloveCard({super.key, required this.session, required this.ble});

  final GloveSession session;
  final GloveBle ble;

  @override
  Widget build(BuildContext context) {
    final link = session.link;
    final connected = link == GloveLink.connected;
    final busy = link == GloveLink.busy;
    final (badge, badgeColor) = connected
        ? ('Connected', AppColors.liveText)
        : busy
            ? ('Connecting', AppColors.yellow)
            : ('Not connected', AppColors.onDarkSoft);
    final sensorLost = connected && !session.motionSensorOk;
    final detail = sensorLost
        ? 'Motion sensor disconnected'
        : link == GloveLink.disconnected && session.status == 'Not connected'
            ? 'Tap Connect to start'
            : session.status;

    return Semantics(
      container: true,
      label: 'SignSuara Glove, $badge',
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(top: -11, left: 14, right: 14, child: _FlagLine()),
            Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(color: AppColors.well, borderRadius: BorderRadius.circular(18)),
                  alignment: Alignment.center,
                  child: HandSensor(bends: fingerBend(session.lastRow), active: connected, size: 50),
                ),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _Dot(color: connected ? AppColors.live : badgeColor),
                        const SizedBox(width: 6),
                        Text(badge.toUpperCase(), style: AppText.eyebrow.copyWith(color: badgeColor)),
                      ]),
                      const SizedBox(height: 2),
                      Text('SignSuara Glove', style: AppText.strong.copyWith(color: AppColors.onDark, fontSize: 15.5)),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small.copyWith(color: sensorLost ? AppColors.danger : AppColors.onDarkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                GloveActionButton(link: link, ble: ble),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlagLine extends StatelessWidget {
  const _FlagLine();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 2,
        child: Row(children: [
          Expanded(child: ColoredBox(color: AppColors.turq)),
          Expanded(child: ColoredBox(color: AppColors.yellow)),
          Expanded(child: ColoredBox(color: AppColors.royal)),
        ]),
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Connect / Disconnect / spinner for the glove, as used on the glove card.
class GloveActionButton extends StatelessWidget {
  const GloveActionButton({super.key, required this.link, required this.ble});

  final GloveLink link;
  final GloveBle ble;

  @override
  Widget build(BuildContext context) {
    return switch (link) {
      GloveLink.busy => const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.yellow),
        ),
      GloveLink.connected => _Pill(
          label: 'Disconnect',
          onTap: ble.disconnect,
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.glassBorder),
          ),
          textColor: AppColors.onDark,
        ),
      GloveLink.disconnected => _Pill(
          label: 'Connect',
          onTap: ble.connect,
          decoration: BoxDecoration(
            gradient: AppGradients.sun,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.sunGlow,
          ),
          textColor: AppColors.onYellow,
        ),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, required this.decoration, required this.textColor});

  final String label;
  final VoidCallback onTap;
  final BoxDecoration decoration;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Ink(
              decoration: decoration,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(label, style: AppText.label.copyWith(color: textColor, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      );
}
