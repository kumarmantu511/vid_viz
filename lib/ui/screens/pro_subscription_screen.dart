import 'package:flutter/material.dart';
import 'package:vidviz/core/config.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/service/pro_service.dart';
import 'package:vidviz/service_locator.dart';

class ProSubscriptionScreen extends StatelessWidget {
  ProSubscriptionScreen({super.key});

  final ProService _proService = locator.get<ProService>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? app_theme.projectListBg : app_theme.background;
    final textPrimary = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    final textSecondary = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;

    return Scaffold
    (
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text(
          'PRO Paketleri',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Daha yüksek çözünürlükler ve gelecekteki PRO özellikler için paket seç.',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ...proPlansConfig.map((plan) => _buildPlanCard(context, plan, isDark)).toList(),
            if (_proService.isProUser) ...[
              const SizedBox(height: 24),
              Text(
                'PRO şu anda aktif',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, ProPlanConfig plan, bool isDark) {
    final textPrimary = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    final textSecondary = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;
    final borderColor = isDark ? app_theme.projectListCardBorder : app_theme.border;
    final cardBg = isDark ? app_theme.projectListCardBg : app_theme.surface;

    final bool isCurrent = _proService.isProUser && _proService.currentPlanId == plan.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? app_theme.accent : borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.subtitle,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                plan.priceText,
                style: TextStyle(
                  color: app_theme.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: isCurrent
                  ? null
                  : () async {
                      await _proService.activatePlan(plan.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? Colors.grey : app_theme.accent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isCurrent ? 'Aktif' : 'Satın al',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
