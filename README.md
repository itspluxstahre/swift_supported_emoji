# Swift Emoji Compiler Compatibility Checker

This project includes a Swift script designed to test the Swift compiler's ability to handle emojis as variable names. It automatically generates Swift code snippets for each emoji from the Emojibase dataset, attempts to compile them, and then categorizes them into "supported" and "unsupported" based on the compilation results. This tool can be particularly useful for developers interested in exploring the limits of Swift's syntax and for those looking to incorporate emojis directly in their code in a novel way.

## Prerequisites

Before you can run the script, ensure your system meets the following requirements:

- **Swift**: The Swift compiler must be installed on your system. This script has been tested with Swift 5.9.x. You can check your Swift version by running `swift --version` in your terminal. For installation instructions, visit [Swift.org](https://swift.org/download/).

## Getting Started

To use this script, you'll need to download the necessary emoji data and then run the script in your terminal. Follow these steps to get started:

### 1. Download Emojibase Data

The script requires the `data.raw.json` file from the Emojibase dataset. Perform the following steps to download this file:

1. Visit the [Emojibase GitHub repository](https://github.com/milesj/emojibase/tree/master/packages/data/en).
2. Navigate to the `data/en` directory.
3. Download the `data.raw.json` file.
4. Place the downloaded file in the same directory as the `convert.swift` script.

### 2. Run the Script

With the `data.raw.json` file in place, you're ready to run the script. Open your terminal, navigate to the directory containing the script and the JSON file, and execute the following command:

```bash
swift convert.swift
```

The script will read the emoji data from `data.raw.json`, generate Swift code for each emoji, attempt to compile each snippet, and then write the results to `supported.swift` and `unsupported.swift` files in the current directory. These files will contain lists of emojis categorized by their compatibility as variable names in Swift.

## Understanding the Output

- **supported.swift**: Contains emojis that were successfully compiled as variable names in Swift. Each line in this file represents a variable declaration using an emoji as the name, followed by a comment with the emoji's label.
  
- **unsupported.swift**: Contains emojis that the Swift compiler could not handle as variable names. Similar to `supported.swift`, each line includes an emoji variable declaration that failed compilation, along with the emoji's label in a comment.

## Conclusion

This project offers a unique way to test and explore the capabilities of the Swift compiler regarding unconventional variable names. It demonstrates how to programmatically interact with the Swift compiler, handle file operations, and parse JSON data in Swift.

Feel free to extend this script or incorporate it into larger projects to further explore Swift's syntactical boundaries.
