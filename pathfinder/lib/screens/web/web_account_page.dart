import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WebAccountPage extends StatelessWidget {
  const WebAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    if (user == null) {
      return const Center(child: Text('No user signed in'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('caretakers')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data();

        final name = data?['name'] ?? user.displayName ?? 'Unknown User';
        final email = data?['email'] ?? user.email ?? 'No email';
        final photoUrl = data?['photoUrl'] ?? user.photoURL;
        final deviceId = data?['deviceId'] ?? 'No linked device';
        final userContactNumber = data?['userContactNumber'] ?? '-';
        final emergencyContactNumber = data?['emergencyContactNumber'] ?? '-';

        return Container(
          color: const Color(0xFFF3F4F6),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 20 : 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Overview',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage caretaker identity, linked device, and emergency contact details.',
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
                const SizedBox(height: 34),

                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 1050),
                  padding: const EdgeInsets.all(34),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 26,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 52,
                                  backgroundColor: const Color(0xFFE0E7FF),
                                  backgroundImage:
                                      photoUrl != null ? NetworkImage(photoUrl) : null,
                                  child: photoUrl == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 52,
                                          color: Color(0xFF3730A3),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Caretaker',
                                    style: TextStyle(
                                      color: Color(0xFF166534),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  email,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Wrap(
                                  spacing: 18,
                                  runSpacing: 18,
                                  children: [
                                    _detailCard(
                                      icon: Icons.devices,
                                      label: 'Linked Device',
                                      value: deviceId,
                                      color: Colors.indigo,
                                      mobile: isMobile,
                                    ),
                                    _detailCard(
                                      icon: Icons.phone,
                                      label: 'Contact Number',
                                      value: userContactNumber,
                                      color: Colors.green,
                                      mobile: isMobile,
                                    ),
                                    _detailCard(
                                      icon: Icons.emergency,
                                      label: 'Emergency Contact',
                                      value: emergencyContactNumber,
                                      color: Colors.red,
                                      mobile: isMobile,
                                    ),
                                    _detailCard(
                                      icon: Icons.badge,
                                      label: 'User ID',
                                      value: user.uid,
                                      color: Colors.deepPurple,
                                      wide: true,
                                      mobile: isMobile,
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 58,
                                      backgroundColor: const Color(0xFFE0E7FF),
                                      backgroundImage:
                                          photoUrl != null ? NetworkImage(photoUrl) : null,
                                      child: photoUrl == null
                                          ? const Icon(
                                              Icons.person,
                                              size: 56,
                                              color: Color(0xFF3730A3),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(height: 18),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Caretaker',
                                        style: TextStyle(
                                          color: Color(0xFF166534),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 36),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        email,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      Wrap(
                                        spacing: 18,
                                        runSpacing: 18,
                                        children: [
                                          _detailCard(
                                            icon: Icons.devices,
                                            label: 'Linked Device',
                                            value: deviceId,
                                            color: Colors.indigo,
                                          ),
                                          _detailCard(
                                            icon: Icons.phone,
                                            label: 'Contact Number',
                                            value: userContactNumber,
                                            color: Colors.green,
                                          ),
                                          _detailCard(
                                            icon: Icons.emergency,
                                            label: 'Emergency Contact',
                                            value: emergencyContactNumber,
                                            color: Colors.red,
                                          ),
                                          _detailCard(
                                            icon: Icons.badge,
                                            label: 'User ID',
                                            value: user.uid,
                                            color: Colors.deepPurple,
                                            wide: true,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool wide = false,
    bool mobile = false,
  }) {
    return Container(
      width: mobile ? double.infinity : (wide ? 650 : 310),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}