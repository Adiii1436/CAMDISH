## Camdish: Effortlessly capture the perfect shot

An intelligent flutter app that lets you take pictures of anything and autozooms to the right size to pick up an object that is in view.<br>
It uses **[google_ml_kit](https://pub.dev/packages/google_ml_kit)** package, specifically it utilizes **[GoogleMLKit.vision.objectDetector](https://pub.dev/packages/google_mlkit_object_detection)** module to detect object and then zoom to the appropriate size of object.

Key features of using [google_ml_kit](https://pub.dev/packages/google_ml_kit) package:
- **Fast object detection** and tracking Detect objects and get their locations in the image. Track objects across successive image frames.
- **Optimized on-device** model The object detection and tracking model is optimized for mobile devices and intended for use in real-time applications, even on lower-end devices.
- **Coarse classification** Classify objects into broad categories, which you can use to filter out objects you're not interested in. The following categories are supported: home goods, fashion goods, food, plants, and places.
- **Classification** with a custom model Use your own custom image classification model to identify or filter specific object categories. Make your custom model perform better by leaving out background of the image.

## How to run the project

- Make sure you have installed flutter and all the requirements
  - [Official flutter installation guide](https://docs.flutter.dev/get-started/install)
- Currently the app uses `3.7.5` flutter version.

In order to run the application, make sure you are in the `CAMDISH` directory and run these commands :

- `flutter pub get`

- On Android 🤖: `flutter run lib/main.dart`


## About this Repository

![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white)