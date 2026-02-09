import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bolo_debate/core/services/api_service.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/features/home/presentation/providers/data_providers.dart';
import 'package:bolo_debate/shared/models/room_model.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sideAController = TextEditingController();
  final _sideBController = TextEditingController();

  String _roomType = 'DEBATE';
  String? _selectedRegionId;
  String? _selectedCategoryId;
  String _selectedLanguage = 'English'; // Default language
  DateTime? _scheduledDateTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _sideAController.dispose();
    _sideBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regionsAsync = ref.watch(regionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Room'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room type selector
              Text(
                'Room Type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TypeCard(
                      title: 'Debate',
                      description: 'Two sides argue their positions',
                      icon: Icons.gavel,
                      isSelected: _roomType == 'DEBATE',
                      onTap: () => setState(() => _roomType = 'DEBATE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeCard(
                      title: 'Discussion',
                      description: 'Open conversation on a topic',
                      icon: Icons.chat_bubble_outline,
                      isSelected: _roomType == 'DISCUSSION',
                      onTap: () => setState(() => _roomType = 'DISCUSSION'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Topic / Title',
                  hintText: 'e.g., Should AI replace human jobs?',
                ),
                maxLength: 200,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a topic';
                  }
                  if (value.length < 5) {
                    return 'Topic must be at least 5 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Add more context about the topic...',
                ),
                maxLines: 3,
                maxLength: 1000,
              ),
              const SizedBox(height: 16),

              // Side labels for debates
              if (_roomType == 'DEBATE') ...[
                Text(
                  'Define the sides',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sideAController,
                        decoration: InputDecoration(
                          labelText: 'Side A',
                          hintText: 'e.g., In Favor',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.sideA.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Text('A', style: TextStyle(color: AppColors.sideA, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        validator: _roomType == 'DEBATE'
                            ? (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sideBController,
                        decoration: InputDecoration(
                          labelText: 'Side B',
                          hintText: 'e.g., Against',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.sideB.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Text('B', style: TextStyle(color: AppColors.sideB, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        validator: _roomType == 'DEBATE'
                            ? (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Region dropdown
              regionsAsync.when(
                data: (regions) => DropdownButtonFormField<String>(
                  value: _selectedRegionId,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  items: regions.map((region) => DropdownMenuItem(
                        value: region.id,
                        child: Text('${region.name}, ${region.state}'),
                      )).toList(),
                  onChanged: (value) {
                    setState(() => _selectedRegionId = value);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a region';
                    }
                    return null;
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Failed to load regions'),
              ),
              const SizedBox(height: 16),

              // Category dropdown
              categoriesAsync.when(
                data: (categories) => DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: categories.map((category) => DropdownMenuItem(
                        value: category.id,
                        child: Row(
                          children: [
                            Text(category.icon),
                            const SizedBox(width: 8),
                            Text(category.name),
                          ],
                        ),
                      )).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategoryId = value);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Failed to load categories'),
              ),
              const SizedBox(height: 16),

              // Language dropdown
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: const InputDecoration(
                  labelText: 'Discussion Language',
                  prefixIcon: Icon(Icons.language_outlined),
                  helperText: 'Choose the primary language for this discussion',
                ),
                items: supportedLanguages.map((language) => DropdownMenuItem(
                      value: language,
                      child: Text(language),
                    )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedLanguage = value);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Schedule date/time
              Text(
                'Schedule',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _scheduledDateTime != null
                              ? DateFormat('EEE, MMM d, y • h:mm a').format(_scheduledDateTime!)
                              : 'Select date and time',
                          style: TextStyle(
                            color: _scheduledDateTime != null ? null : Colors.grey,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
              if (_scheduledDateTime == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: Text(
                    'Room must be scheduled at least 30 minutes in advance',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ),

              const SizedBox(height: 32),

              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Rooms are live for 30 minutes. As a host, you can extend up to 3 times (5 min each).',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Create button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createRoom,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Room'),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final minTime = now.add(const Duration(minutes: 30));

    final date = await showDatePicker(
      context: context,
      initialDate: minTime,
      firstDate: minTime,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(minTime),
    );

    if (time == null) return;

    final selectedDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (selectedDateTime.isBefore(minTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time at least 30 minutes from now')),
      );
      return;
    }

    setState(() => _scheduledDateTime = selectedDateTime);
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.createRoom(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        regionId: _selectedRegionId!,
        categoryId: _selectedCategoryId!,
        type: _roomType,
        sideALabel: _roomType == 'DEBATE' ? _sideAController.text.trim() : null,
        sideBLabel: _roomType == 'DEBATE' ? _sideBController.text.trim() : null,
        language: _selectedLanguage,
        scheduledAt: _scheduledDateTime!,
      );

      if (response['success'] == true) {
        final roomId = response['data']['id'];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room created successfully!')),
        );
        context.go('/room/$roomId/detail');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['error'] ?? 'Failed to create room')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
