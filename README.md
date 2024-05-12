# Greetings Board App

[![Build and Publish Docker Image](https://github.com/yogendra/greetings-app/actions/workflows/build-and-publish.yaml/badge.svg)](https://github.com/yogendra/greetings-app/actions/workflows/build-and-publish.yaml)

![](greerings-app.png)

This is a simple greetings board application built with FastAPI, HTMX, and PostgreSQL. It allows users to post greetings with their GitHub avatars and messages.

## Features

- **Real-time Updates:** Greetings are added and updated without full page reloads, thanks to HTMX.
- **GitHub Avatars:** Users can easily add their GitHub avatars to their greetings.
- **Tailwind CSS:** The UI is styled using Tailwind CSS for a modern and customizable look.
- **Dockerized:**  The app is containerized using Docker for easy development and deployment.

## Getting Started

### Prerequisites

- Docker
- Docker Compose (if you want to run the database locally)

### Installation

1. Clone the repository:

   ```bash
   git clone [invalid URL removed]
   ```

2. Set up environment variables:

    ```bash
    cp .env.example .env
    ```

3. Start the application:

    ```bash
    docker-compose up -d
    ```


The application will be available at `http://localhost:8000`.



## Usage
1. Enter your GitHub ID in the form.
2. Type your message in the message box.
3. Click the "Post Greeting" button.
4. Your greeting will appear on the board!


## For Developers

### Development Setup

1. Follow the instructions in the "Getting Started" section.
2. You can use the included docker-compose.yaml file to start the application and database in development mode.
The application will run with hot reloading, so changes to the code will be reflected automatically.

### Technologies Used
- **Backend:** FastAPI
- **Frontend:** HTML, HTMX, Tailwind CSS
- **Database:** PostgreSQL
- **Containerization:** Docker


### Development Workflow
* Use your preferred IDE (e.g., Visual Studio Code) with the Remote - Containers extension for a streamlined development environment.
* Edit the code, and the changes will be reflected live thanks to FastAPI's hot reloading.

### Contributing
Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch (git checkout -b feature/your-feature-name).
3. Make your changes and commit them (git commit -m 'Add some feature').
4. Push to the branch (git push origin feature/your-feature-name).
5. Create a pull request.



## License
This project is licensed under the MIT License.
