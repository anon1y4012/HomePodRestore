# HomePod Restore Tool

This is the HomePod Restore Tool, designed to simplify the process of restoring your Apple HomePod using custom firmware. This tool allows you to flash IPSW files and manage dependencies, making the restore process straightforward for Mac users.

## Features

- Verifies and installs necessary dependencies for HomePod restoration.
- Creates and flashes custom IPSW files for the HomePod.
- Simple and user-friendly graphical interface using CustomTkinter.

## Prerequisites

- **Operating System**: macOS
- **Python**: Version 3.10 or above (automatically handled by the setup script)
- **HomePod**: Ensure your HomePod is ready for the restore process.

## Installation

### 1. Clone the Repository

First, clone the repository to your local machine:

```bash
git clone https://github.com/yourusername/HomePodRestoreTool.git
cd HomePodRestoreTool```

### 2. Running the Setup Script (Recommended)

To simplify the installation process, you can run the provided setup script:

```bash
chmod +x setup.sh
./setup.sh
```

This script will:
- Install Miniconda if it's not already installed.
- Create a Python virtual environment using Miniconda.
- Install all necessary Python dependencies.

### 3. Manual Installation (If you prefer)

If you prefer to set up the environment manually, follow these steps:

#### a. Install Miniconda

Download and install Miniconda:

```bash
curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -o Miniconda3-latest-MacOSX.sh
bash Miniconda3-latest-MacOSX.sh
```

#### b. Create a Virtual Environment

Create and activate a virtual environment:

```bash
conda create -n homepodenv python=3.10
conda activate homepodenv
```

#### c. Install Python Dependencies

Install the required Python packages:

```bash
pip install -r requirements.txt
```

## Usage

After setting up the environment, you can run the HomePod Restore Tool:

```bash
python restorer.py
```

### Key Features

- **Verify Dependencies**: The tool will check if all necessary dependencies are installed on your system.
- **Install Dependencies**: Automatically installs any missing dependencies using Homebrew.
- **Create IPSW**: Generates custom IPSW files using your HomePod firmware.
- **Flash IPSW**: Flashes the generated IPSW file to your HomePod.

## Troubleshooting

### Common Issues

1. **Dependency Errors**:
   - Ensure that Homebrew is installed on your system.
   - Verify that your Python version is 3.10 or above.

2. **Script Not Running**:
   - Make sure that you have activated the virtual environment using \`conda activate homepodenv\`.
   - Verify that all paths in the script are correctly set relative to your cloned repository location.

### Reporting Bugs

If you encounter any issues, please open an issue on the [GitHub repository](https://github.com/yourusername/HomePodRestoreTool/issues).

## Contributing

We welcome contributions! If you have any improvements or features to add, feel free to fork this repository, make your changes, and submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.