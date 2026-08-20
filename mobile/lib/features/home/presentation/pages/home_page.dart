import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vivido',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              Icon(
                Icons.home_work_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 24),

              Text(
                "Vivido'ya Hoş Geldin",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 12),

              Text(
                'Kiralık evlerini keşfet, kişiselleştirilmiş skorlarını '
                'incele ve ziyaret rotanı oluştur.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: Colors.black54, height: 1.5),
              ),

              const SizedBox(height: 32),

              const FilledButton(
                onPressed: null,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Giriş Yap'),
                ),
              ),

              const SizedBox(height: 12),

              const OutlinedButton(
                onPressed: null,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Rotalarım'),
                ),
              ),

              const Spacer(),

              Text(
                'API: ${AppConfig.apiBaseUrl}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
