import 'package:flutter/material.dart';
import '../../utils/colors.dart';

// NOTE: Habol ko

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({Key? key}) : super(key: key);

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluation'),
      ),
      body: const Center(
        child: Text(
          'Onboarding Content',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}