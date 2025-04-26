# KMP Migration Tool

A tool for migrating Android and iOS projects to Kotlin Multiplatform (KMP).

## Features

- Automatic migration of Android and iOS projects to KMP
- Creation of the `shared` module structure with all necessary configurations
- Automatic Gradle configuration with:
  - Version Catalog
  - Gradle Wrapper
  - KMP settings
- Support for:
  - Existing Android projects
  - Existing iOS projects
- Option to move or not move app content to the new structure
- Preservation of important files during migration
- Automatic namespace and dependency configuration

## Prerequisites

- Java 11 or higher (If you want to use Java 8, feel free to update the build.gradle.kts templates)
- Android Studio (for Android projects)
- Xcode (for iOS projects)

## Installation

1. Clone this repository
2. Make the script executable:
```bash
chmod +x scripts/migrate_to_kmp.sh
```

## Usage

### For Android Projects

1. Run the script:
```bash
./scripts/migrate_to_kmp.sh
```

2. Enter the full path to your Android project when prompted
3. Enter the package name when prompted (e.g., com.example.app)
4. Choose whether to move the app content to the `androidApp` folder
5. The script will:
   - Create the `shared` module structure
   - Configure Gradle
   - Move app content (if chosen)
   - Create the `iosApp` folder for future development (you can use [to-mono](https://github.com/hraban/tomono) to move the iOS module while preserving its history)

### For iOS Projects

1. Run the script:
```bash
./scripts/migrate_to_kmp.sh
```

2. Enter the full path to your iOS project when prompted
3. Enter the package name when prompted (e.g., com.example.app)
4. Choose whether to move the project content to the `iosApp` folder
5. The script will:
   - Create the `shared` module structure
   - Configure Gradle
   - Move project content (if chosen)
   - Create the `androidApp` folder for future development

### For New Projects

1. Run the script:
```bash
./scripts/migrate_to_kmp.sh
```

2. Enter the path where you want to create the new project
3. Enter the package name when prompted (e.g., com.example.app)
4. The script will:
   - Create the complete KMP project structure
   - Configure Gradle
   - Create both `androidApp` and `iosApp` folders

## Project Structure After Migration

```
project/
├── androidApp/           # Android Application
├── iosApp/              # iOS Application
├── shared/              # Shared Module
│   ├── src/
│   │   ├── commonMain/  # Common Code
│   │   ├── androidMain/ # Android-specific Code
│   │   └── iosMain/     # iOS-specific Code
│   └── build.gradle.kts
├── gradle/
│   └── wrapper/         # Gradle Wrapper
├── build.gradle.kts     # Project Configuration
├── settings.gradle.kts  # Module Configuration
└── gradle.properties    # Gradle Properties
```

## Next Steps

1. Add your shared code to `shared/src/commonMain/kotlin`
2. Implement platform-specific code in:
   - `shared/src/androidMain/kotlin`
   - `shared/src/iosMain/kotlin`
3. Run the build to verify everything is configured correctly
4. Start migrating your business logic to the `shared` module

## Support

If you encounter any issues or have suggestions, please open an issue in the repository.

## References

### What is KMP?
- [Kotlin Multiplatform Mobile (KMM) Documentation](https://kotlinlang.org/docs/multiplatform-mobile-getting-started.html)
- [Kotlin Multiplatform Overview](https://kotlinlang.org/docs/multiplatform.html)

### KMP Migration Guides
- [Migrating to Kotlin Multiplatform Mobile](https://kotlinlang.org/docs/multiplatform-mobile-migrate.html)
- [Kotlin Multiplatform Mobile Migration Guide](https://kotlinlang.org/docs/multiplatform-mobile-migrate.html)

### KMP Setup Guides
- [Setting Up a KMP Project](https://kotlinlang.org/docs/multiplatform-mobile-setup.html)
- [Kotlin Multiplatform Project Structure](https://kotlinlang.org/docs/multiplatform-project-structure.html)
- [Kotlin Multiplatform Dependencies](https://kotlinlang.org/docs/multiplatform-dependencies.html) 