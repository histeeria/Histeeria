import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/services/activity_service.dart';

class SearchHistoryScreen extends StatefulWidget {
  const SearchHistoryScreen({super.key});

  @override
  State<SearchHistoryScreen> createState() => _SearchHistoryScreenState();
}

class _SearchHistoryScreenState extends State<SearchHistoryScreen> {
  final ActivityService _activityService = ActivityService();
  List<String> _searches = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final searches = await _activityService.getSearchHistory();
      setState(() {
        _searches = searches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Recent Searches',
            style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
          ),
          actions: [
            if (_searches.isNotEmpty)
              TextButton(
                onPressed: () {
                  // TODO: Clear search history
                },
                child: Text('Clear All', style: TextStyle(color: AppColors.accentPrimary)),
              )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text('Error: $_errorMessage'))
                : _searches.isEmpty
                    ? Center(
                        child: Text(
                          'No recent searches',
                          style: AppTextStyles.bodyLarge(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _searches.length,
                        itemBuilder: (context, index) {
                          final search = _searches[index];
                          return ListTile(
                            leading: Icon(Icons.history, color: AppColors.textSecondary),
                            title: Text(search, style: AppTextStyles.bodyLarge(color: AppColors.textPrimary)),
                            trailing: IconButton(
                              icon: Icon(Icons.close, color: AppColors.textTertiary, size: 20),
                              onPressed: () {
                                // TODO: Delete single search item
                              },
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
