import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/colors.dart';
import '../models/profile.dart';

class UserAvatar extends StatelessWidget {
  final Profile? profile;
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.profile,
    this.radius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String initial = profile?.displayName.isNotEmpty == true
        ? profile!.displayName[0].toUpperCase()
        : 'S';
    final String? avatarUrl = profile?.avatarUrl;
    final bool hasUrl = avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http');

    Widget avatar = hasUrl
        ? CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.2),
            backgroundImage: CachedNetworkImageProvider(avatarUrl),
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }

    return avatar;
  }
}
