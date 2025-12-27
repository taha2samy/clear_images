
# Production-Ready Distroless Dockerfiles

Standard Docker images are not built for production. They are often bloated, run as `root`, and present a significant security risk. This repository provides a practical, scalable pattern for creating **hardened, minimal, and secure** Docker images using best-in-class techniques.

This project demonstrates this methodology with initial implementations for **Nginx** and **Redis**, providing a blueprint that can be adapted for any service.

![alt text](/images/image copy.png)

## 1. Guiding Principles: The "Why"

The core philosophy of this project is to build images that are secure by default, not as an afterthought. This is achieved by adhering to three fundamental principles that address the common failings of standard container images.

*   #### **Security First**
    Every image is built to adhere to the **principle of least privilege**. All processes run as a **non-root user**, and every non-essential binary, library, and utility is aggressively removed. If a component is not strictly required for the service to function, it does not belong in the final image, drastically minimizing the potential attack surface.

*   #### **Minimalism by Design**
    We achieve extreme minimalism through two key techniques: **multi-stage builds** completely separate the build-time tools from the final artifact, and **Google's Distroless images** serve as the final base. The resulting images contain only the application and its direct dependencies—no shell, no package manager, and no unnecessary bloat.

*   #### **Automated Assurance**
    Security is not a one-time check; it's a continuous process. A comprehensive **CI pipeline using GitHub Actions** provides automated assurance for every commit. It acts as a security gate, ensuring that every Dockerfile is automatically linted, every image is scanned for vulnerabilities, and every change is validated against our security policies before it can proceed.



## 2. Technical Implementation: The "How"

This repository provides initial implementations for **Nginx** and **Redis**, but the techniques used represent a standardized hardening pattern that can be applied to virtually any service. By understanding these methods, you can extend this project to include your own applications.

Our approach transforms a standard, often insecure, Docker setup into a hardened, minimal artifact.

![alt text](/images/image.png)
*   #### **Multi-Stage Builds: Separating Build from Runtime**
    Every Dockerfile uses a multi-stage build pattern. The first stage, named `builder`, is based on a standard image (e.g., `nginx-unprivileged`). This stage acts as a temporary workspace where we have access to tools like `apt-get` and `ldd`. Once we have compiled the application or gathered the necessary artifacts, we discard this entire stage. The final stage starts from a clean `distroless` base and copies *only* the essential files, leaving all build-time tools and dependencies behind.
    **[Link: Docker's Guide to Multi-Stage Builds]**

*   #### **Distroless Images: The Minimalist Foundation**
    The final image for each service is built `FROM gcr.io/distroless/cc-debian12:nonroot`. These base images, maintained by Google, are the cornerstone of our security strategy. They are "distro-less" because they contain only the bare minimum set of shared libraries needed to run an application and nothing more.
    - No shell (`/bin/sh`).
    - No package manager (`apt`, `apk`).
    - No standard Linux utilities (`ls`, `cat`, `ps`).
    This extreme minimalism drastically shrinks the attack surface.
    **[Link: Official Google Distroless Repository](https://github.com/GoogleContainerTools/distroless)**

*   #### **Automated Dependency Discovery**
    Manually identifying every shared library (`.so` file) an application needs is tedious and error-prone. For Nginx, we automated this process in the `builder` stage with a simple but powerful command:
    ```bash
    RUN apt-get update && apt-get install -y libc-bin gawk && \
        mkdir /deps && \
        ldd /usr/sbin/nginx | awk 'NF == 4 {print $3};' | xargs -I {} cp -v {} /deps
    ```
    This command uses `ldd` to list all of Nginx's dependencies and then copies them into a temporary directory. The final stage can then reliably copy this complete set of libraries, ensuring the Dockerfile remains robust even if future Nginx versions have different dependencies.

*   #### **Deliberate Hardening and File Management**
    Beyond the base image, we take explicit steps to harden the final artifact:
    - **Non-Root Execution:** We copy the `passwd` and `group` files from the `builder` and use the `USER nginx` (or `USER redis`) instruction to ensure the application process runs without root privileges.
    - **Minimal Binary Set:** We consciously omit non-essential binaries. For example, `redis-sentinel` is excluded from the Redis image because it is not required for a standalone server, further reducing potential vulnerabilities.

---
### **Image and Link Suggestions for this Section:**

*   **For `[Image: Image Size Comparison (Default vs. Distroless)]`:**
    *   **Best Option:** Create a simple bar chart comparing the final image sizes. For example: `Official Nginx (142MB)` vs. `Our Hardened Nginx (21MB)`. Visualizing this massive size reduction is incredibly impactful.
    *   **Alternative:** Use a tool like `dive` to analyze both the official image and your new image. A side-by-side screenshot showing the reduction in layers and wasted space would be very effective.

*   **For the Links:**
    *   **`[Link: Docker's Guide to Multi-Stage Builds]`**: Link to the official Docker documentation page that explains multi-stage builds.
    *   **`[Link: Official Google Distroless Repository]`**: Link directly to the `github.com/GoogleCloudPlatform/distroless` repository.



## 3. Automated Assurance: The CI/CD Pipeline

To guarantee that every image produced in this repository adheres to our high standards, we have integrated a comprehensive CI pipeline using **GitHub Actions**. This automated workflow serves as a security gatekeeper, ensuring that best practices are not just recommended, but enforced with every single commit.

The pipeline is designed to be transparent, thorough, and to provide actionable feedback directly within the GitHub ecosystem.

**[Image: Successful GitHub Actions Pipeline Run]**

Our CI pipeline is broken down into logical jobs and steps:

*   #### **Pre-Build Security Audit**
    Before any code is built, the `security-audit` job runs first. It uses **Gitleaks** to scan the entire repository history for any accidentally committed secrets, API keys, or other sensitive credentials. This preventative step ensures our codebase itself is clean.

*   #### **Build, Lint, and Scan Matrix Job**
    This is the core of our validation process. It runs as a [matrix job](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs) for each service (`nginx`, `redis`), allowing it to scale easily as new services are added. For each service, it performs the following critical steps:

    1.  **Dockerfile Linting with Hadolint:** Before building, each `Dockerfile` is analyzed by Hadolint. This linter checks for common mistakes, stylistic errors, and deviations from established best practices, ensuring the quality and maintainability of our build definitions.

    2.  **Comprehensive Vulnerability Scanning with Trivy:** This is the cornerstone of our security validation. After the image is built, **Trivy** performs a deep scan of its contents, including all OS packages and libraries, searching for known common vulnerabilities and exposures (CVEs).

    3.  **Automated Policy Enforcement:** The pipeline doesn't just report findings; it enforces a strict security policy. **The build will automatically fail if Trivy detects any `CRITICAL` or `HIGH` severity vulnerabilities that have an available fix.** This critical step prevents insecure images from ever being considered for deployment.

    4.  **Generation of Security Artifacts:** To provide full visibility, the pipeline generates a suite of reports that are uploaded as build artifacts:
        *   **SARIF Report:** A standardized format that is automatically ingested by GitHub. This populates the "Security" tab of the repository with detailed vulnerability information.
        *   **HTML Report:** A user-friendly, self-contained report that is ideal for manual reviews and sharing with stakeholders.
        *   **SBOM Report (SPDX format):** A **Software Bill of Materials** that provides a complete inventory of all software components within the image. This is essential for modern software supply chain security and compliance.

By automating these checks, we ensure a consistent, repeatable, and secure process for building and maintaining our production-ready Docker images.

**[Link: View the CI Pipeline in Action]**

---
### **Image and Link Suggestions for this Section:**

*   **For `[Image: Successful GitHub Actions Pipeline Run]`:**
    *   **Best Option:** A screenshot of a successful run from the "Actions" tab in your GitHub repository. It should show the `security-audit` job and the two `build-and-test-services` matrix jobs with green checkmarks next to them. This provides immediate visual proof that your entire process works.

*   **For the Link:**
    *   **`[Link: View the CI Pipeline in Action]`**: Link directly to the "Actions" tab of your repository (e.g., `https://github.com/your-username/your-repo/actions`). This is a powerful call to action that lets users see the results for themselves.