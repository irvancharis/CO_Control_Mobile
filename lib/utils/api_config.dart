class ApiConfig {
  // Variabel statis untuk menyimpan Base URL
  static String baseUrl = "";

  // Fungsi helper untuk menyusun URL lengkap
  static String getUrl(String endpoint) {
    return "$baseUrl$endpoint";
  }
}
