# Operate the cluster from this dev box via SSH to the control plane.
# (T14 has no local kubectl — the control plane does; we stream manifests to it.)
KCP    ?= ashah@10.0.0.30
KUBECTL := ssh $(KCP) kubectl

.PHONY: help nodes deploy-llm deploy-app probe-up monitoring-up status clean-app

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

nodes: ## Show cluster nodes
	$(KUBECTL) get nodes -o wide

deploy-llm: ## Deploy the Ollama Service + EndpointSlice (in-cluster LLM endpoint)
	ssh $(KCP) 'kubectl apply -f -' < apps/ollama/ollama-service.yaml

deploy-app: ## Deploy the multi-arch hello app (runs on both arm64 + amd64)
	ssh $(KCP) 'kubectl apply -f -' < apps/hello-arch/deployment.yaml

probe-up: ## Deploy the blackbox LLM availability/latency probe
	ssh $(KCP) 'kubectl apply -f -' < monitoring/blackbox-probe.yaml

monitoring-up: ## Print the kube-prometheus-stack install command (see monitoring/README.md)
	@echo 'helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \'
	@echo '  -n monitoring --create-namespace -f monitoring/values.yaml'

status: ## Show app / llm / monitoring pods
	@$(KUBECTL) get pods -n llm -o wide 2>/dev/null; echo
	@$(KUBECTL) get pods -l app=hello-arch -o wide 2>/dev/null; echo
	@$(KUBECTL) get pods -n monitoring 2>/dev/null

clean-app: ## Remove the hello app
	ssh $(KCP) 'kubectl delete -f -' < apps/hello-arch/deployment.yaml
