import 'package:flutter/material.dart';

class NotificationBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const NotificationBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.notifications,
    this.color = Colors.blue,
    this.onDismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(title + message),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
