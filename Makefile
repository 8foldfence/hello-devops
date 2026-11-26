.PHONY: test run platform deploy argocd argocd-password grafana alerts down

## --- Local development ---
test:            ## lint + unit tests (same checks CI runs)
	ruff check . && pytest -v

run:             ## run the website locally on http://localhost:8000
	uvicorn app.main:app --reload

## --- Platform on your laptop ---
platform:        ## Terraform: create kind cluster + Argo CD + monitoring (~5 min)
	cd infra && terraform init && terraform apply -auto-approve

deploy:          ## hand the app to Argo CD (one-time)
	kubectl --context kind-hello-devops apply -f argocd/application.yaml

argocd:          ## Argo CD UI on http://localhost:8081 (user: admin)
	@echo "Password: $$(kubectl --context kind-hello-devops -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	kubectl --context kind-hello-devops -n argocd port-forward svc/argocd-server 8081:80

grafana:         ## Grafana on http://localhost:3000 (admin / admin)
	kubectl --context kind-hello-devops -n monitoring port-forward svc/monitoring-grafana 3000:80

alerts:          ## Alertmanager on http://localhost:9093
	kubectl --context kind-hello-devops -n monitoring port-forward svc/monitoring-kube-prometheus-alertmanager 9093:9093

down:            ## delete everything
	cd infra && terraform destroy -auto-approve
