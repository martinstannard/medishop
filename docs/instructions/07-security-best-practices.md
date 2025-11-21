# 7. Security Best Practices (Elixir/Phoenix/Ash)

Security is a primary concern in software development. You must follow these best practices to ensure that the code you write is secure.

## 7.1. Never Commit Secrets

Never commit secrets, API keys, passwords, or other sensitive data to the repository. Use Elixir's `config/runtime.exs` (or `releases.exs` for older versions) to load secrets from environment variables at runtime. For more complex scenarios, consider a secret management tool (e.g., Vault, AWS Secrets Manager).

## 7.2. Sanitize Inputs and Prevent XSS

Phoenix and Ash provide strong protection against common vulnerabilities.

*   **Prevent SQL Injection:** The `Ecto` library, used by Ash, relies on parameterized queries, which is the gold standard for preventing SQL injection. Always use Ecto's query syntax and never manually interpolate strings into queries.
*   **Prevent Cross-Site Scripting (XSS):** Phoenix's HEEx templates automatically escape all content by default. Continue to rely on this feature and avoid using `raw()` with untrusted user input.

## 7.3. Use Dependency Scanning

Use `mix hex.audit` to check for known vulnerabilities in your project's dependencies. If a vulnerability is found, update the library to a secure version.

## 7.4. Use Security-Focused Static Analysis

Use `sobelow`, a security-focused static analysis tool for the Phoenix framework. Run it as part of your CI/CD pipeline to automatically detect potential vulnerabilities.

```bash
mix sobelow --exit
```

## 7.5. Follow the Principle of Least Privilege

When designing systems, follow the principle of least privilege. In Ash, this means defining restrictive authorizers and policies for your resources and only opening up access as needed. Do not define a `bypass` authorizer unless it is absolutely necessary and well-documented.
