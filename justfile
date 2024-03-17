work:
    zellij action new-tab --cwd . --name feaston --layout zellij_layout.kdl
auto-reload:
    systemfd --no-pid -s http::3000 -- cargo watch -x run
tailwind:
    tailwindcss -i styles/tailwind.css -o assets/main.css --watch
