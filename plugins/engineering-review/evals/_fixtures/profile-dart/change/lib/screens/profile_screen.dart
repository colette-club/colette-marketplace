import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:app/cubits/profile_cubit.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _bioController = TextEditingController();

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await context.read<ProfileCubit>().save(_bioController.text);
    if (saved) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProfileCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(cubit.mainCubit.viewerCubit.state.viewer.address.city.name)),
      body: TextField(controller: _bioController),
      floatingActionButton: FloatingActionButton(onPressed: _save, child: const Icon(Icons.check)),
    );
  }
}
