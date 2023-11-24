import 'dart:convert';
import 'package:escribo_2_ebook/model/book_model.dart';
import 'package:http/http.dart' as http;

class BookRepository {
  // Pegando os dados da API:
  Future<List<BookModel>> getBooks() async {
    final response =
        await http.get(Uri.parse('https://escribo.com/books.json'));
    if (response.statusCode == 200) {
      List<BookModel> books = List<BookModel>.from(
          json.decode(response.body).map((data) => BookModel.fromJson(data)));

      // lets print out the title property
      //books.forEach((element) {
      //  print(element.title);
      //});

      return books;
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to load book!');
    }
  }
}
