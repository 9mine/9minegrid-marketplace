FROM 9mine/9p-execfuse-jinja2:master
RUN curl -fsSLo get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && install kubectl /usr/local/bin
RUN apt install git -y
RUN helm repo add 9mine https://9mine.github.io/charts
RUN helm repo update 