# Lab 01 — Go Language Justification

## Why Go?

For the compiled language implementation of the DevOps Info Service, I chose **Go**.

### Key Advantages

- **Static Binaries**: Go compiles all dependencies into a single static binary. This is ideal for containerization (Lab 2), as it allows for extremely small Docker images using `scratch` or `alpine` bases.
- **Performance**: As a compiled language, Go offers significantly better performance and lower memory footprint compared to Python/FastAPI.
- **Standard Library**: Go's `net/http` package is exceptionally robust, allowing the creation of a production-ready web server without any external dependencies.
- **DevOps Ecosystem**: Go is the "lingua franca" of modern DevOps tooling (Docker, Kubernetes, Terraform, and Prometheus are all written in Go).

### Comparison with Alternatives

| Feature | Go | Rust | Java (Spring Boot) |
|---------|----|------|--------------------|
| **Compilation Speed** | Extremely Fast | Slow | Medium |
| **Binary Size** | Small (~7MB) | Small (~4MB) | Large (50MB+ JAR) |
| **Memory Usage** | Very Low | Extremely Low | High (JVM overhead) |
| **Learning Curve** | Low | High | Medium |
| **Suitability for K8s** | Excellent | Excellent | Moderate |

## Conclusion

Go provides the perfect balance of development speed, runtime performance, and minimal resource usage, making it the most practical choice for a DevOps-oriented microservice.
