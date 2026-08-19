import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  final String password;

  int _calculateStrength() {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return score;
  }

  Color _getStrengthColor(int strength) {
    switch (strength) {
      case 1:
        return const Color(0xFFE53935); // Red
      case 2:
        return const Color(0xFFFB8C00); // Orange
      case 3:
        return const Color(0xFFFDD835); // Yellow
      case 4:
        return const Color(0xFF43A047); // Emerald green
      default:
        return Colors.grey.shade400;
    }
  }

  String _getStrengthLabel(int strength) {
    switch (strength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return 'Enter password';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = _calculateStrength();
    final strengthColor = _getStrengthColor(strength);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasMinLength = password.length >= 8;
    final hasUpperAndLower =
        RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password strength',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _getStrengthLabel(strength),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: strengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(4, (index) {
            final isFilled = index < strength;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: index < 3 ? 6 : 0,
                ),
                height: 4,
                decoration: BoxDecoration(
                  color: isFilled
                      ? strengthColor
                      : (isDark ? Colors.white12 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildRequirementPill('8+ chars', hasMinLength, isDark),
            _buildRequirementPill('Aa Upper/Lower', hasUpperAndLower, isDark),
            _buildRequirementPill('123 Number', hasNumber, isDark),
            _buildRequirementPill('#@! Symbol', hasSpecial, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementPill(String text, bool isMet, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isMet
            ? const Color(0xFF43A047).withValues(alpha: 0.15)
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMet
              ? const Color(0xFF43A047).withValues(alpha: 0.4)
              : (isDark ? Colors.white10 : Colors.grey.shade300),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 12,
            color: isMet
                ? const Color(0xFF43A047)
                : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMet
                  ? const Color(0xFF2E7D32)
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
