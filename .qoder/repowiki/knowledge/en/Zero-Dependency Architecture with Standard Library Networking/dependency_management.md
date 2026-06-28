The FactShield repository employs a **zero-dependency** strategy for its core application logic, relying exclusively on Apple's native frameworks and standard library capabilities. 

### System Approach
- **Package Manager**: The project uses Swift Package Manager (SPM) as indicated by the `Package.swift` file. However, the `dependencies` array is explicitly empty (`[]`), confirming that no third-party libraries are declared or managed via SPM.
- **Networking**: Instead of popular third-party networking libraries like Alamofire or AFNetworking, the project implements a custom, actor-based `APIClient` using `URLSession` and `async/await`. This client handles JSON serialization, error handling, and exponential backoff retries internally.
- **Concurrency & State**: The app leverages Apple's native `Combine` framework for reactive state management (e.g., in `FactCheckCoordinator`) and `OSLog` for structured logging, avoiding external dependencies for these common concerns.

### Key Files
- `FactShield/Package.swift`: Defines the package structure with an empty dependency list.
- `FactShield/FactShield/Core/Network/APIClient.swift`: A custom, robust networking layer implementing retry logic and error handling without external tools.
- `FactShield/FactShield/Core/Network/QwenAPI.swift` & `SearchAPI.swift`: Service-specific API clients built on top of the custom `APIClient`.
- `FactShield/FactShield/Utilities/Constants.swift`: Centralizes configuration constants, including API base URLs, reducing the need for external configuration libraries.

### Architecture and Conventions
- **Self-Contained Network Layer**: The `APIClient` is implemented as a singleton `actor`, ensuring thread-safe access to the shared `URLSession`. It provides generic methods for both typed decoding (`Decodable`) and raw JSON dictionary responses, offering flexibility without external JSON parsing libraries like SwiftyJSON.
- **Protocol-Oriented Search**: The `SearchAPI.swift` file defines a `SearchProvider` protocol, allowing for interchangeable search implementations (e.g., Tavily, Google Fact Check) while maintaining a consistent internal interface. This promotes testability and modularity without requiring a dependency injection framework.
- **Environment-Based Configuration**: API keys and sensitive configurations are retrieved from `ProcessInfo.processInfo.environment` or `UserDefaults`, adhering to standard iOS security practices without needing external secrets management libraries.

### Rules for Developers
1. **No Third-Party Libraries**: Do not add new dependencies to `Package.swift` unless absolutely necessary and approved. The project aims to minimize supply chain risk and build complexity by using native Apple frameworks.
2. **Use Native Networking**: All HTTP requests must go through the existing `APIClient` actor. Do not create ad-hoc `URLSession` instances; instead, extend the `APIClient` if new features (like multipart uploads) are needed.
3. **Standard Library First**: Prefer `Foundation`, `Combine`, and `OSLog` for common tasks. Avoid introducing external libraries for JSON parsing, logging, or dependency injection.
4. **Configuration Management**: Add new API endpoints or configuration values to `Constants.swift` or use environment variables for secrets. Do not hardcode URLs or keys in service files.