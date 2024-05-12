FROM mcr.microsoft.com/vscode/devcontainers/python:3.10-bullseye


# Install custom tools, runtime, etc.
RUN set -e \
  && apt-get update \
  && apt-get install -qqy fzf direnv tmux vim bat postgresql-13 \
  && chmod a+rwx /var/run/postgresql \
  && ln -s /usr/bin/batcat /usr/bin/bat \
  && chsh -s /usr/bin/zsh root \
  && chsh -s /usr/bin/zsh vscode \
  && echo 'export PATH=$PATH:/usr/lib/postgresql/13/bin' >> /etc/zsh/zshrc \
  && echo "source /usr/share/doc/fzf/examples/completion.zsh" >> /etc/zsh/zshrc \
  && echo "source /usr/share/doc/fzf/examples/key-bindings.zsh" >> /etc/zsh/zshrc \
  && echo "source /usr/share/bash-completion/completions/fzf" >> /etc/bash.bashrc \
  && echo "source /usr/share/doc/fzf/examples/key-bindings.bash" >> /etc/bash.bashrc \
  && echo 'eval "$(direnv hook bash)"'>> /etc/bash.bashrc \
  && curl -sS https://starship.rs/install.sh | sh -s -- -y \
  && echo 'eval "$(starship init zsh)"' >> /etc/zsh/zshrc \
  && echo 'eval "$(starship init bash)"' >> /etc/bash.bashrc \
  && curl -sSL https://raw.githubusercontent.com/yogendra/dotfiles/master/.tmux.conf-ng -o ~/.tmux.conf \
  && install -o vscode -g vscode /root/.tmux.conf /home/vscode/.tmux.conf

ENV PGDATABASE=postgres
ENV PGUSER=postgres
