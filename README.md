# Moonrelay - A Professional Matrix Client

**Moonrelay** is a cross-platform Matrix client designed for professional usage and advanced users. It prioritizes stability, security, and a clean, intuitive interface. This document provides an overview of the project, its features, installation instructions, and contribution guidelines.

## Features

* ~~**Secure Communication:** Built with strong encryption using Matrix's secure protocol.~~ Broken
* **Cross-Platform Support:** Natively targets Linux and Windows. More platforms possible.
* **Room Management:** Create, join, and manage rooms efficiently.
* **Message Handling:** Send text, images, files, and other Matrix message types. Supports rich formatting.
* **User Profiles:** Manage your user profile information.
* **Search Functionality:** Quickly find users and rooms within your matrix network.
* **Customizable Themes:** Adjust the app's appearance to suit your preferences.
* **Advanced Settings:** Configure various settings, including security options and notification preferences.

## Installation

Release/CI is not yet available, you will need to build from source.

### Build from source

#### Desktop (Windows, Linux)

Download [Flutter](flutter.dev) according to your host platform and follow the installation instructions.

1. Clone the repository: `git clone https://codeberg.org/SurenaSKQ/moonrelay.git`
2. Navigate to the Flutter project directory: `cd moonrelay`
3. Build and run the desktop application using the appropriate command for your operating system:

    * **Windows:** `flutter run -d windows`
    * **Linux:** `flutter run -d linux`

## Dependencies

The project relies on several key libraries.  A list of dependencies is in the `pubspec.yaml` file. Key dependencies include:

* **matrix:** The matrix dart sdk from Famedly.
* **fluent_ui:** Provides a modern, customizable UI toolkit.
* **provider:** For state management.
* **go_router:**  For navigation within the app.

## Contributing

We welcome contributions from the community! Here's how you can contribute:

1. **Fork the repository:** [https://codeberg.org/SurenaSKQ/moonrelay](https://codeberg.org/SurenaSKQ/moonrelay)
2. **Create a new branch for your feature or bug fix:** `git checkout -b my-new-feature`
3. **Make your changes and commit them with descriptive messages.**
4. **Push your branch to your fork on GitHub:** `git push origin my-new-feature`
5. **Create a pull request from your fork to the main repository.**

## License

This project is licensed under the [GNU Affero General Public License v3](https://www.gnu.org/licenses/agpl-3.0.html). See the `LICENSE.txt` file for details.

## Contact

* **GitHub:** [https://codeberg.org/SurenaSKQ/moonrelay](https://codeberg.org/SurenaSKQ/moonrelay)
* **Issue Tracker:** [https://codeberg.org/SurenaSKQ/moonrelay/issues](https://codeberg.org/SurenaSKQ/moonrelay/issues)
