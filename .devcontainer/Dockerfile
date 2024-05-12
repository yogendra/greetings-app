FROM mcr.microsoft.com/vscode/devcontainers/python:3.10-bullseye


# Install custom tools, runtime, etc.
RUN set -e \
  && apt-get update \
  && apt-get install -qqy fzf direnv tmux vim bat \
  && ln -s /usr/bin/batcat /usr/bin/bat \
  && chsh -s /usr/bin/zsh root \
  && chsh -s /usr/bin/zsh vscode \
  && echo "source /usr/share/doc/fzf/examples/completion.zsh" >> /root/.zshrc \
  && echo "source /usr/share/doc/fzf/examples/key-bindings.zsh" >> /root/.zshrc \
  && echo "source /usr/share/doc/fzf/examples/completion.zsh" >> /home/vscode/.zshrc \
  && echo "source /usr/share/doc/fzf/examples/key-bindings.zsh" >> /home/vscode/.zshrc \
  && echo "source /usr/share/bash-completion/completions/fzf" >> /root/.bashrc \
  && echo "source /usr/share/doc/fzf/examples/key-bindings.bash" >> /root/.bashrc \
  && echo "source /usr/share/bash-completion/completions/fzf" >> /home/vscode/.bashrc \
  && echo "source /usr/share/doc/fzf/examples/key-bindings.bash" >> /home/vscode/.bashrc \
  && echo 'eval "$(direnv hook zsh)"'>> /root/.zshrc \
  && echo 'eval "$(direnv hook zsh)"'>> /root/.zshrc \
  && echo 'eval "$(direnv hook bash)"'>> /home/vscode/.bashrc \
  && echo 'eval "$(direnv hook bash)"'>> /home/vscode/.bashrc \
  && curl -sS https://starship.rs/install.sh | sh -s -- -y \
  && echo 'eval "$(starship init zsh)"' >> ~/.zshrc \
  && echo 'eval "$(starship init bash)"' >> ~/.bashrc \
  && echo 'eval "$(starship init zsh)"' >> /home/.zshrc \
  && echo 'eval "$(starship init bash)"' >> /home/.bashrc \
  && curl -sSL https://raw.githubusercontent.com/yogendra/dotfiles/master/.tmux.conf-ng -o ~/.tmux.conf \
  && install -o vscode -g vscode /root/.tmux.conf /home/vscode/.tmux.conf
