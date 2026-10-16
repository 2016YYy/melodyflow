import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 分组标题
class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// 信息行（标签 + 值，纵向排列）
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// 圆角图标盒
class IconBox extends StatelessWidget {
  final IconData icon;
  final ThemePalette palette;
  const IconBox({super.key, required this.icon, required this.palette});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        color: palette.primary.withValues(alpha: 0.14),
      ),
      child: Icon(icon, color: scheme.primary, size: 22),
    );
  }
}

/// 操作行（图标盒 + 标题 + 副标题 + 可选尾部）
class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ThemePalette palette;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.palette,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: IconBox(icon: icon, palette: palette),
      title: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: trailing ??
          Icon(Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

/// 开关行（图标盒 + 标题 + 副标题 + 开关）
class SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ThemePalette palette;
  final ValueChanged<bool> onChanged;

  const SwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: IconBox(icon: icon, palette: palette),
      title: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
