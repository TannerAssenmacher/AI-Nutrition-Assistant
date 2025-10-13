import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nameController = TextEditingController(text: "Alex McNutrition");
  final TextEditingController heightController = TextEditingController(text: "6'2\"");
  final TextEditingController weightController = TextEditingController(text: "200 lbs.");
  final List<String> allergies = ["Gluten (Breads)", "Apples", "Salmon"];

  void _addAllergy() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController allergyInput = TextEditingController();
        return AlertDialog(
          title: const Text("Add Allergy"),
          content: TextField(
            controller: allergyInput,
            decoration: const InputDecoration(hintText: "e.g., Dairy"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final newAllergy = allergyInput.text.trim();
                if (newAllergy.isNotEmpty && !allergies.contains(newAllergy)) {
                  setState(() {
                    allergies.add(newAllergy);
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _removeAllergy() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedAllergy;
        return AlertDialog(
          title: const Text("Remove Allergy"),
          content: DropdownButtonFormField<String>(
            value: allergies.isNotEmpty ? allergies[0] : null,
            items: allergies.map((a) {
              return DropdownMenuItem(value: a, child: Text(a));
            }).toList(),
            onChanged: (value) {
              selectedAllergy = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (selectedAllergy != null) {
                  setState(() {
                    allergies.remove(selectedAllergy);
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text("Remove"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFFF1DCC4); // beige color
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text("ainutrition Assistant", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        foregroundColor: Colors.brown,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundImage: AssetImage('assets/profile_placeholder.png'), // Replace with your image
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: TextField(
                    controller: heightController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: TextField(
                    controller: weightController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addAllergy,
              child: const Text("+ Add Allergies"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _removeAllergy,
              child: const Text("- Remove Allergies"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.brown),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: allergies
                    .map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(a),
                ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Save action
              },
              child: const Text("Save"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Meal Plan'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Camera'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
