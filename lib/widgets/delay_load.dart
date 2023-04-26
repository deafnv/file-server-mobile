import 'package:flutter/material.dart';

class StaggeredLoading extends StatelessWidget {
  const StaggeredLoading({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 100)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.secondary,
            ),
          );
        } else {
          return Container();
        }
      },
    );
  }
}
