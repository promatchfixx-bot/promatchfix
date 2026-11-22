import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _client
        .from('service_categories')
        .select('id, name_th, name_en, slug, icon')
        .eq('is_active', true)
        .order('id');

    return List<Map<String, dynamic>>.from(response);
  }
}
