# 🤖 AI-ROADMAP.md

This document outlines the **roadmap for AI integration** with the **unifi-edtech-stack**.

---

## 📌 Phase 1: Ingest UniFi Logs

- Use `docker run -v ./unifi-logs:/data ollama/ollama` to ingest logs.
- Convert logs to text format for AI training.
- Use `docker logs unifi > unifi-logs/adoption-$(date).txt` to capture logs.

---

## 📌 Phase 2: Fine-Tune LLM

- Use `ollama create edtech-ops -f Modelfile` to fine-tune Llama3 on your logs.
- Track model versions with `git lfs track "*.gguf"`.
- Use `ollama serve` to run the model locally.

---

## 📌 Phase 3: Integrate with UniFi Alerts

- Use Ollama API to query AI for insights (e.g., "Predict AP dropout from logs").
- Integrate with Alertmanager for real-time alerts.
- Use `curl` or `jq` to parse AI outputs.

---

## 📌 Phase 4: Automate with Git

- Use `git commit` to version AI models and logs.
- Set up CI/CD for model updates and deployment.
- Use GitHub Actions or GitHub Pages for model hosting.

---

## 📌 Notes

- AI is a **tool**, not a **replacement** for human insight.
- Always **validate AI outputs** with real-world data.
- Use **versioning** for AI models and logs.