import 'package:flutter/material.dart';
import 'screens/main_menu_screen.dart';

void main() {
	runApp(const CardGamesApp());
}

class CardGamesApp extends StatelessWidget {
	const CardGamesApp({super.key});
	@override
	Widget build(BuildContext context) {
		return MaterialApp(
			debugShowCheckedModeBanner: false,
			theme: ThemeData.dark().copyWith(
				scaffoldBackgroundColor: const Color(0xFF0F172A),
				colorScheme: const ColorScheme.dark(
					primary: Color(0xFF1E3A8A),
					secondary: Color(0xFFBDA468),
				),
				textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
			),
			home: const MainMenuScreen(),
		);
	}
}

