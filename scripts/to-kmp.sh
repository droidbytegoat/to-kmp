#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

validate_directory() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        print_error "Error: Directory '$dir' does not exist. Please check the path and try again."
        return 1
    fi
    return 0
}

validate_directory_access() {
    local dir=$1
    if ! cd "$dir" 2>/dev/null; then
        print_error "Error: Could not access directory '$dir'. Please check permissions and try again."
        return 1
    fi
    return 0
}

validate_package_name() {
    local package_name=$1
    if [ -z "$package_name" ]; then
        print_error "Error: Package name cannot be empty. Please provide a valid package name."
        return 1
    fi
    
    if ! [[ "$package_name" =~ ^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$ ]]; then
        print_error "Error: Invalid package name format."
        print_error "Package name must:"
        print_error "- Start with a lowercase letter"
        print_error "- Contain only lowercase letters, numbers, and underscores"
        print_error "- Have at least two segments separated by dots"
        print_error "Example: com.example.app"
        return 1
    fi
    
    return 0
}

get_project_root() {
    local project_root=""
    local current_dir=$(pwd)
    local project_type=""
    
    while true; do
        printf "Enter the full path of the project root directory: " >&2
        read -r project_root
        
        if [ -z "$project_root" ]; then
            print_error "Error: Path cannot be empty. Please provide a valid path."
            continue
        fi
        
        project_root=$(eval echo "$project_root")
        
        if [ ! -d "$project_root" ]; then
            print_error "Error: Directory '$project_root' does not exist. Please check the path and try again."
            continue
        fi
        
        if ! cd "$project_root" 2>/dev/null; then
            print_error "Error: Could not access directory '$project_root'. Please check permissions and try again."
            continue
        fi
        
        if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] || [ -f "app/build.gradle" ] || [ -f "app/build.gradle.kts" ]; then
            project_type="android"
            print_message "Detected Android project at: $project_root" >&2
            cd "$current_dir"
            local absolute_path=$(cd "$project_root" && pwd)
            echo "$absolute_path|$project_type"
            break
        fi

        if [ -f "Podfile" ] || find . -maxdepth 1 -name "*.xcodeproj" -o -name "*.xcworkspace" | grep -q . || find . -name "project.pbxproj" | grep -q .; then
            project_type="ios"
            print_message "Detected iOS project at: $project_root" >&2
            cd "$current_dir"
            local absolute_path=$(cd "$project_root" && pwd)
            echo "$absolute_path|$project_type"
            break
        fi
        
        print_error "Error: Could not identify project type (Android/iOS)."
        print_error "Please make sure the directory contains either:"
        print_error "- For Android: build.gradle or build.gradle.kts"
        print_error "- For iOS: Podfile, .xcodeproj, or .xcworkspace"
        cd "$current_dir"
        continue
    done
}

get_package_name() {
    local package_name=""
    
    while true; do
        printf "Enter package name (ex: com.example.app): " >&2
        read -r package_name
        
        if [ -z "$package_name" ]; then
            print_error "Error: Package name cannot be empty. Please provide a valid package name."
            continue
        fi
        
        if ! [[ "$package_name" =~ ^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$ ]]; then
            print_error "Error: Invalid package name format."
            print_error "Package name must:"
            print_error "- Start with a lowercase letter"
            print_error "- Contain only lowercase letters, numbers, and underscores"
            print_error "- Have at least two segments separated by dots"
            print_error "Example: com.example.app"
            continue
        fi
        
        echo "$package_name"
        break
    done
}

read_template() {
    local template_name=$1
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local template_path="$script_dir/templates/$template_name.txt"
    
    if [ ! -f "$template_path" ]; then
        print_error "Error: Template file not found: $template_path"
        print_error "Current directory: $(pwd)"
        print_error "Script directory: $script_dir"
        print_error "Template path: $template_path"
        print_error "Template files available: $(ls -la $script_dir/templates/ 2>/dev/null || echo 'No templates directory found')"
        exit 1
    fi
    
    cat "$template_path"
}

copy_templates() {
    local project_root=$1
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    print_message "Copying templates from $script_dir/templates to $project_root/templates..."
    
    if [ ! -d "$script_dir/templates" ]; then
        print_error "Error: Templates directory not found at $script_dir/templates"
        exit 1
    fi
    
    mkdir -p "$project_root/templates"
    cp -R "$script_dir/templates/"* "$project_root/templates/"
}

create_templates() {
    local package_name=$1
    local app_name=$(basename "$package_name")
    local shared_namespace="$package_name.shared"
    local android_namespace="$package_name.android"
    
    print_message "Creating configuration templates..."
    
    if ! cd "$PROJECT_ROOT"; then
        print_error "Failed to change to project directory: $PROJECT_ROOT"
        print_error "Current directory: $(pwd)"
        print_error "Please check if the directory exists and you have proper permissions."
        exit 1
    fi
    
    local version_catalog_path="gradle/libs.versions.toml"
    if [ ! -f "$version_catalog_path" ]; then
        print_message "Creating version catalog..."
        read_template "version_catalog" > "$version_catalog_path"
    else
        print_message "Version catalog already exists. Updating with KMP dependencies..."
        
        local temp_file=$(mktemp)
        cat "$version_catalog_path" > "$temp_file"
        
        if ! grep -q "agp = " "$temp_file"; then
            sed -i '' '/\[versions\]/a\
agp = "8.1.0"\
' "$temp_file"
        fi
        
        if ! grep -q "kotlin = " "$temp_file"; then
            sed -i '' '/\[versions\]/a\
kotlin = "1.9.22"\
' "$temp_file"
        fi
        
        if ! grep -q "compose = " "$temp_file"; then
            sed -i '' '/\[versions\]/a\
compose = "1.5.0"\
' "$temp_file"
        fi
        
        if ! grep -q "compose-material3 = " "$temp_file"; then
            sed -i '' '/\[versions\]/a\
compose-material3 = "1.1.1"\
' "$temp_file"
        fi
        
        if ! grep -q "androidx-activityCompose = " "$temp_file"; then
            sed -i '' '/\[versions\]/a\
androidx-activityCompose = "1.7.2"\
' "$temp_file"
        fi
        
        if ! grep -q "compose-bom = " "$temp_file"; then
            sed -i '' '/\[libraries\]/a\
compose-bom = { module = "androidx.compose:compose-bom", version = "2025.02.00" }\
' "$temp_file"
        fi
        
        if ! grep -q "kotlin-test = " "$temp_file"; then
            sed -i '' '/\[libraries\]/a\
kotlin-test = { module = "org.jetbrains.kotlin:kotlin-test", version.ref = "kotlin" }\
' "$temp_file"
        fi
        
        if ! grep -q "androidx-activity-compose = " "$temp_file"; then
            sed -i '' '/\[libraries\]/a\
androidx-activity-compose = { module = "androidx.activity:activity-compose", version.ref = "androidx-activityCompose" }\
' "$temp_file"
        fi
        
        if ! grep -q "compose-ui = " "$temp_file"; then
            sed -i '' '/\[libraries\]/a\
compose-ui = { module = "androidx.compose.ui:ui", version.ref = "compose" }\
' "$temp_file"
        fi
        
        if ! grep -q "compose-ui-tooling = " "$temp_file"; then
            sed -i '' '/\[libraries\]/a\
compose-ui-tooling = { module = "androidx.compose.ui:ui-tooling", version.ref = "compose" }\
' "$temp_file"
        fi
        
        if ! grep -q "compose-ui-tooling-preview = " "$temp_file"; then
            sed -i '' '/\[libraries\]/a\
compose-ui-tooling-preview = { module = "androidx.compose.ui:ui-tooling-preview", version.ref = "compose" }\
' "$temp_file"
        fi
        
        if ! grep -q "compose-foundation = " "$temp_file"; then
            sed -i '' '/\[libraries\]/a\
compose-foundation = { module = "androidx.compose.foundation:foundation", version.ref = "compose" }\
' "$temp_file"
        fi
        
        if ! grep -q "compose-material3 = " "$temp_file"; then
            sed -i '' '/\[libraries\]/a\
compose-material3 = { module = "androidx.compose.material3:material3", version.ref = "compose-material3" }\
' "$temp_file"
        fi
        
        if ! grep -q "id = \"com.android.application\"" "$temp_file"; then
            sed -i '' '/\[plugins\]/a\
android-application = { id = "com.android.application", version.ref = "agp" }\
' "$temp_file"
        fi
        
        if ! grep -q "id = \"com.android.library\"" "$temp_file"; then
            sed -i '' '/\[plugins\]/a\
android-library = { id = "com.android.library", version.ref = "agp" }\
' "$temp_file"
        fi
        
        if ! grep -q "id = \"org.jetbrains.kotlin.android\"" "$temp_file"; then
            sed -i '' '/\[plugins\]/a\
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }\
' "$temp_file"
        fi
        
        if ! grep -q "id = \"org.jetbrains.kotlin.multiplatform\"" "$temp_file"; then
            sed -i '' '/\[plugins\]/a\
kotlin-multiplatform = { id = "org.jetbrains.kotlin.multiplatform", version.ref = "kotlin" }\
' "$temp_file"
        fi
        
        if ! grep -q "id = \"org.jetbrains.kotlin.native.cocoapods\"" "$temp_file"; then
            sed -i '' '/\[plugins\]/a\
kotlin-cocoapods = { id = "org.jetbrains.kotlin.native.cocoapods", version.ref = "kotlin" }\
' "$temp_file"
        fi
        
        if ! grep -q "id = \"org.jetbrains.kotlin.plugin.compose\"" "$temp_file"; then
            sed -i '' '/\[plugins\]/a\
compose-compiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }\
' "$temp_file"
        fi
        
        mv "$temp_file" "$version_catalog_path"
    fi
    
    print_message "Creating settings.gradle.kts..."
    if [ ! -f "settings.gradle.kts" ]; then
        if [ "$PROJECT_TYPE" = "android" ]; then
            read_template "settings_gradle" > "settings.gradle.kts"
        else
            local project_name=$(basename "$PROJECT_ROOT")
            read_template "settings_gradle" | sed "s/\$project_name/$project_name/g" > "settings.gradle.kts"
        fi
    else
        local temp_file=$(mktemp)
        cat "settings.gradle.kts" > "$temp_file"
        
        if ! grep -q "enableFeaturePreview" "$temp_file"; then
            sed -i '' '1i\
enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")\
' "$temp_file"
        fi
        
        if ! grep -q "include(\":shared\")" "$temp_file"; then
            sed -i '' '/include(/a\
include(":shared")\
' "$temp_file"
        fi
        
        mv "$temp_file" "settings.gradle.kts"
    fi
    
    print_message "Creating build.gradle.kts..."
    if [ ! -f "build.gradle.kts" ]; then
        read_template "root_build_gradle" > "build.gradle.kts"
    else
        local temp_file=$(mktemp)
        cat "build.gradle.kts" > "$temp_file"
        
        local required_plugins=(
            "android.application"
            "android.library"
            "kotlin.android"
            "kotlin.multiplatform"
            "kotlin.cocoapods"
            "compose.compiler"
        )
        
        for plugin in "${required_plugins[@]}"; do
            local plugin_exists=false
            local catalog_alias=""
            
            case $plugin in
                "android.application")
                    local variations=("android.application" "androidapplication" "android-application")
                    ;;
                "android.library")
                    local variations=("android.library" "androidlibrary" "android-library")
                    ;;
                "kotlin.android")
                    local variations=("kotlin.android" "kotlinandroid" "kotlin-android")
                    ;;
                "kotlin.multiplatform")
                    local variations=("kotlin.multiplatform" "kotlinmultiplatform" "kotlin-multiplatform")
                    ;;
                "kotlin.cocoapods")
                    local variations=("kotlin.cocoapods" "kotlincocoapods" "kotlin-cocoapods")
                    ;;
                *)
                    local variations=("$plugin")
                    ;;
            esac
            
            for variation in "${variations[@]}"; do
                if grep -q "alias(libs.plugins.$variation)" "$temp_file"; then
                    plugin_exists=true
                    break
                fi
            done
            
            if [ "$plugin_exists" = false ]; then
                if [ "$plugin" = "compose.compiler" ]; then
                    sed -i '' "/plugins {/a\\
    alias(libs.plugins.compose.compiler) apply false\\
" "$temp_file"
                else
                    sed -i '' "/plugins {/a\\
    alias(libs.plugins.$plugin) apply false\\
" "$temp_file"
                fi
            fi
        done
        
        mv "$temp_file" "build.gradle.kts"
    fi
    
    if [ ! -f "gradle.properties" ]; then
        read_template "gradle_properties" > "gradle.properties"
    fi

    if [ ! -f "shared/build.gradle.kts" ]; then
        mkdir -p "shared"
        read_template "shared_build_gradle" | sed "s/\$shared_namespace/$shared_namespace/g" > "shared/build.gradle.kts"
    fi
}

ask_app_content_movement() {
    local platform=$1
    local response=""
    
    while true; do
        printf "Do you want to move the existing $platform app content to ${platform}App? (y/n): " >&2
        read -r response
        
        case $response in
            [Yy]* ) echo "yes"; break;;
            [Nn]* ) echo "no"; break;;
            * ) print_error "Please answer yes or no.";;
        esac
    done
}

setup_kmp_structure() {
    local shared_namespace=$1
    print_message "Setting up KMP structure..."
    
    cd "$PROJECT_ROOT" || {
        print_error "Failed to change to project directory: $PROJECT_ROOT"
        exit 1
    }
    
    print_message "Setting up Gradle structure..."
    mkdir -p "gradle/wrapper"
    
    if [ ! -f "gradle/libs.versions.toml" ]; then
        read_template "version_catalog" > "gradle/libs.versions.toml"
    fi
    
    if [ ! -f "build.gradle.kts" ]; then
        read_template "root_build_gradle" > "build.gradle.kts"
    fi
    
    if [ ! -f "gradlew" ] || [ ! -f "gradle/wrapper/gradle-wrapper.jar" ] || [ ! -f "gradle/wrapper/gradle-wrapper.properties" ]; then
        print_message "Setting up Gradle wrapper..."
        
        cat > "gradle/wrapper/gradle-wrapper.properties" << EOF
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF
        
        print_message "Downloading gradle-wrapper.jar..."
        curl -L -o "gradle/wrapper/gradle-wrapper.jar" "https://raw.githubusercontent.com/gradle/gradle/master/gradle/wrapper/gradle-wrapper.jar"
        
        print_message "Creating gradlew script..."
        read_template "gradlew" > "gradlew"
        chmod +x "gradlew"
        
        print_message "Creating gradlew.bat script..."
        read_template "gradlew.bat" > "gradlew.bat"
        
        print_message "Gradle wrapper setup completed successfully!"
    fi
    
    print_message "Creating shared module structure..."
    mkdir -p "shared/src/commonMain/kotlin"
    mkdir -p "shared/src/commonMain/resources"
    
    mkdir -p "shared/src/androidMain/kotlin"
    mkdir -p "shared/src/androidMain/resources"
    
    mkdir -p "shared/src/iosMain/kotlin"
    mkdir -p "shared/src/iosMain/resources"
    
    if [ ! -f "shared/build.gradle.kts" ]; then
        read_template "shared_build_gradle" | sed "s/\$shared_namespace/$shared_namespace/g" > "shared/build.gradle.kts"
    fi
    
    if [ "$PROJECT_TYPE" = "android" ]; then
        print_message "Setting up Android structure..."
        if [ -d "app" ]; then
            local move_content=$(ask_app_content_movement "Android")
            if [ "$move_content" = "yes" ]; then
                print_message "Moving app module content to androidApp..."
                mkdir -p "androidApp"
                cp -R "app/." "androidApp/"
                rm -rf "app"
                
                if [ -f "settings.gradle.kts" ]; then
                    sed -i '' 's/include(":app")/include(":androidApp")/g' "settings.gradle.kts"
                fi
                
                if [ ! -f "androidApp/build.gradle.kts" ]; then
                    read_template "android_app_build_gradle" | sed "s/\$android_namespace/$android_namespace/g" > "androidApp/build.gradle.kts"
                fi

                print_message "Creating empty iosApp directory for future iOS development..."
                mkdir -p "iosApp"
            else
                print_message "Skipping Android app setup. Only shared module will be created."
            fi
        else
            print_message "No existing Android app found. Only shared module will be created."
        fi
    fi
    
    if [ "$PROJECT_TYPE" = "ios" ]; then
        print_message "Setting up iOS structure..."
        if [ -f "Podfile" ] || find . -maxdepth 1 -name "*.xcodeproj" -o -name "*.xcworkspace" | grep -q . || find . -name "project.pbxproj" | grep -q .; then
            local move_content=$(ask_app_content_movement "iOS")
            if [ "$move_content" = "yes" ]; then
                print_message "Moving iOS app content to iosApp..."
                mkdir -p "iosApp"
                
                find . -maxdepth 1 -not -name "." \
                    -not -name "iosApp" \
                    -not -name "shared" \
                    -not -name "gradle" \
                    -not -name ".gradle" \
                    -not -name "*.kts" \
                    -not -name "*.toml" \
                    -not -name "gradlew" \
                    -not -name "gradlew.bat" \
                    -not -name "gradle.properties" \
                    -exec mv {} iosApp/ \;

                print_message "Creating empty androidApp directory for future Android development..."
                mkdir -p "androidApp"
            else
                print_message "Skipping iOS app setup. Only shared module will be created."
            fi
        else
            print_message "No existing iOS app found. Only shared module will be created."
        fi
    fi

    print_message "KMP structure set up successfully!"
}

cleanup_templates() {
    print_message "Cleaning up temporary files..."
    
    if [ -f "libs.versions.toml.tmp" ]; then
        rm -f "libs.versions.toml.tmp"
    fi
    
    if [ -f "root.build.gradle.kts.tmp" ]; then
        rm -f "root.build.gradle.kts.tmp"
    fi
    
    if [ -f "settings.gradle.kts.tmp" ]; then
        rm -f "settings.gradle.kts.tmp"
    fi
    
    if [ -f "shared.build.gradle.kts.tmp" ]; then
        rm -f "shared.build.gradle.kts.tmp"
    fi
    
    if [ -f "androidApp.build.gradle.kts.tmp" ]; then
        rm -f "androidApp.build.gradle.kts.tmp"
    fi
    
    if [ -f "gradle.properties.tmp" ]; then
        rm -f "gradle.properties.tmp"
    fi
}

main() {
    print_message "Starting KMP setup..."
    
    local project_info=$(get_project_root)
    PROJECT_ROOT=$(echo "$project_info" | cut -d'|' -f1)
    PROJECT_TYPE=$(echo "$project_info" | cut -d'|' -f2)
    
    print_message "Project root: $PROJECT_ROOT"
    print_message "Project type: $PROJECT_TYPE"
    
    if [ -z "$PROJECT_ROOT" ] || [ -z "$PROJECT_TYPE" ]; then
        print_error "Failed to determine project root or type. Aborting."
        exit 1
    fi
    
    local package_name=$(get_package_name)
    local shared_namespace="$package_name.shared"
    
    create_templates "$package_name"
    
    setup_kmp_structure "$shared_namespace"
    
    cleanup_templates
    
    print_message "KMP setup completed successfully!"
    print_message "Next steps:"
    print_message "1. Review the new KMP structure"
    print_message "2. Start adding your shared code in shared/src/commonMain/kotlin"
    print_message "3. Run build to verify everything is working"
}

main 