// Copyright (C) 2024 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <https://www.gnu.org/licenses/>.
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LoadingAndTransitionScreen extends StatefulWidget {
  const LoadingAndTransitionScreen({super.key});

  @override
  State<LoadingAndTransitionScreen> createState() =>
      _LoadingAndTransitionScreenState();
}

class _LoadingAndTransitionScreenState
    extends State<LoadingAndTransitionScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            color: Colors.transparent,
            gradient: LinearGradient(
              colors: [Colors.black, Colors.white30],
            ),
          ),
          child: const Center(
            child: SpinKitCubeGrid(
              color: Colors.indigo,
            ),
          ),
        ),
      ),
    );
  }
}
