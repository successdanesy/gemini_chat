// ignore: unused_import
// ignore_for_file: unused_import, duplicate_ignore, unnecessary_import, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ignore: unused_import
import 'package:animate_do/animate_do.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
// ignore: unused_import
import 'package:gemini_chat_app_tutorial/feature_box.dart';
import 'package:gemini_chat_app_tutorial/pallete.dart'; // Make sure this import is correct
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Gemini gemini = Gemini.instance;
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  List<ChatMessage> messages = [];

  ChatUser currentUser = ChatUser(id: "0", firstName: "User");
  ChatUser geminiUser = ChatUser(
    id: "1",
    firstName: "Gemini",
    profileImage: 'assets/images/virtualAssistant.png', // Adjust path as needed
  );

  bool _showListeningIndicator = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Gemini Chat"),
        leading: const Icon(Icons.menu),
      ),
      body: Column(
        children: [
          Container(
            height: 120,
            width: 120,
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('assets/images/virtualAssistant.png'), // Replace with your image
          ),
          Expanded(
            child: DashChat(
              inputOptions: InputOptions(
                trailing: [
                  IconButton(
                    onPressed: _sendMediaMessage,
                    icon: const Icon(Icons.image),
                  ),
                  IconButton(
                    onPressed: _isListening ? _stopListening : _startListening,
                    icon: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.all(_showListeningIndicator ? 10 : 8),
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              currentUser: currentUser,
              onSend: _sendMessage,
              messages: messages,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
    });
    try {
      String question = chatMessage.text;
      List<Uint8List>? images;
      if (chatMessage.medias?.isNotEmpty ?? false) {
        images = [
          File(chatMessage.medias!.first.url).readAsBytesSync(),
        ];
      }
      gemini.streamGenerateContent(question, images: images).listen((event) {
        if (messages.isNotEmpty) {
          ChatMessage lastMessage = messages.first; // No need for firstOrNull since we checked if messages is not empty

          if (lastMessage.user == geminiUser) {
            lastMessage.text += event.content?.parts?.fold(
                    "", (previous, current) => "$previous ${current.text}") ??
                "";
            setState(() {}); 
          } else {
            String response = event.content?.parts?.fold(
                    "", (previous, current) => "$previous ${current.text}") ??
                "";
            ChatMessage message = ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              text: response,
            );
            setState(() {
              messages = [message, ...messages];
            });
          }
        } else { 
          String response = event.content?.parts?.fold(
                  "", (previous, current) => "$previous ${current.text}") ??
              "";
          ChatMessage message = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: response,
          );
          setState(() {
            messages = [message, ...messages];
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }


  void _sendMediaMessage() async {
    ImagePicker picker = ImagePicker();
    XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      ChatMessage chatMessage = ChatMessage(
        user: currentUser,
        createdAt: DateTime.now(),
        text: "Describe this picture?",
        medias: [
          ChatMedia(
            url: file.path,
            fileName: "",
            type: MediaType.image,
          )
        ],
      );
      _sendMessage(chatMessage);
    }
  }

  void _startListening() async {
    bool available = await _speechToText.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _showListeningIndicator = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listening...'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
      // Custom positioning:
      margin: EdgeInsets.only(bottom: 80.0), // Adjust the bottom margin as needed
        ),
      );

      _speechToText.listen(
        onResult: (result) => setState(() => _recognizedText = result.recognizedWords),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not available'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _stopListening() async {
    setState(() {
      _isListening = false;
      _showListeningIndicator = false;
    });
    await _speechToText.stop();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (_recognizedText.isNotEmpty) {
      _sendMessage(ChatMessage(
        user: currentUser,
        createdAt: DateTime.now(),
        text: _recognizedText,
      ));
      setState(() => _recognizedText = '');
    }
  }
}
