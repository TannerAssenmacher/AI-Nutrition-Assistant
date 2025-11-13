import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_chat_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _showRecipePicker = false;

  String? _selectedMealType;
  bool _showCuisinePicker = false;
  bool _showConfirmationButtons = false;


  final List<String> _cuisineTypes = [
    'American',
    'Asian',
    'British',
    'Caribbean',
    'Central Europe',
    'Chinese',
    'Eastern Europe',
    'French',
    'Greek',
    'Indian',
    'Italian',
    'Japanese',
    'Korean',
    'Kosher',
    'Mediterranean',
    'Mexican',
    'Middle Eastern',
    'Nordic',
    'South American',
    'South East Asian',
    'None',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    ref.read(geminiChatServiceProvider.notifier).sendMessage(message);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _promptRecipeType() {
    // Bot says the prompt, then show quick buttons
    ref.read(geminiChatServiceProvider.notifier).promptForRecipeType();
    setState(() {
      _showRecipePicker = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

 void _onRecipeTypeSelected(String type) {
  setState(() {
    _selectedMealType = type;
    _showRecipePicker = false;
    _showCuisinePicker = true; // cuisines
  });

  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
}


void _onCuisineSelected(String cuisine) {
  setState(() => _showCuisinePicker = false);

  final meal = _selectedMealType ?? 'Meal';

  ref
      .read(geminiChatServiceProvider.notifier)
      .handleMealTypeSelection(meal, cuisine); //send info to the backend

  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
}


  @override
  Widget build(BuildContext context) {
    final chatMessages = ref.watch(geminiChatServiceProvider);
  
    //user confirmation
    if (chatMessages.isNotEmpty &&
          chatMessages.last.content.contains("Is this correct?") &&
          !_showConfirmationButtons) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _showConfirmationButtons = true);
        });
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Assistant Chat'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Chat',
            onPressed: () {
              ref.read(geminiChatServiceProvider.notifier).clearChat();
              setState(() => _showRecipePicker = false);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: chatMessages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Ask me anything about nutrition!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try: "What should I eat for dinner?"',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = chatMessages[index];
                      return _ChatBubble(message: message);
                    },
                  ),
          ),

          // Quick meal-type picker
          if (_showRecipePicker)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: Colors.grey[100],
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => _onRecipeTypeSelected('Breakfast'),
                    child: const Text('Breakfast'),
                  ),
                  ElevatedButton(
                    onPressed: () => _onRecipeTypeSelected('Lunch'),
                    child: const Text('Lunch'),
                  ),
                  ElevatedButton(
                    onPressed: () => _onRecipeTypeSelected('Dinner'),
                    child: const Text('Dinner'),
                  ),
                  ElevatedButton(
                    onPressed: () => _onRecipeTypeSelected('Snack'),
                    child: const Text('Snack'),
                  ),
                ],
              ),
            ),
          //cuisine type picker
         if (_showCuisinePicker)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a cuisine type for your $_selectedMealType:',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cuisineTypes.map((cuisine) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => _onCuisineSelected(cuisine),
                        child: Text(
                          cuisine,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

           //confirmation on user diet and health restrictions
            if (_showConfirmationButtons)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[100],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Is this information correct?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            // ✅ user confirms info is correct
                            setState(() => _showConfirmationButtons = false);
                            ref
                                .read(geminiChatServiceProvider.notifier)
                                .confirmMealProfile(true);
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => _scrollToBottom());
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Yes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            // ❌ user says info is incorrect
                            setState(() => _showConfirmationButtons = false);
                            ref
                                .read(geminiChatServiceProvider.notifier)
                                .confirmMealProfile(false);
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => _scrollToBottom());
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('No'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

          // Message input + Generate Recipes button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _promptRecipeType,
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text('Generate Recipes'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText:
                              'Ask about nutrition, calories, meal planning...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: _sendMessage,
                      backgroundColor: Colors.green[600],
                      mini: true,
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.green[600],
              radius: 16,
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.green[600] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.formattedTime,
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isUser ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue[600],
              radius: 16,
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
