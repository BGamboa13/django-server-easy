#!/bin/bash

# Función para imprimir mensajes con formato de título
print_title() {
    echo "== $1 =="
}

# Función para imprimir mensajes con formato de subsección
print_subtitle() {
    echo "-- $1 --"
}

# Función para instalar paquetes y manejar errores
install_package() {
    sudo apt-get -qq install "$1" || { echo "Error al instalar $1"; exit 1; }
}

# Función para levantar el servidor
start_server() {
    sudo systemctl restart nginx
    sudo supervisorctl restart all
}

# Función para obtener la opción del usuario (actualizar o crear)
get_user_option() {
    read -p "Seleccione una opción: 
    1. Actualizar un certificado existente para un proyecto.
    2. Clonar y configurar un nuevo proyecto.
    3. Salir.
    Su elección (1/2/3): " user_choice

    case $user_choice in
        1 ) update_existing_project;;
        2 ) clone_and_configure_project;;
        3 ) exit;;
        * ) echo "Opción no válida. Por favor, seleccione una opción válida (1/2/3).";;
    esac
}

# Función para actualizar un proyecto existente
update_existing_project() {
    print_subtitle "PROYECTOS EXISTENTES:"
    # Listar todos los proyectos en el directorio /home/django
    projects=(/home/django/*)
    for ((i=0; i<${#projects[@]}; i++)); do
        echo "$(($i+1)). ${projects[$i]##*/}"
    done
    
    # Solicitar al usuario que seleccione un número de proyecto
    read -p "Seleccione el número del proyecto que desea actualizar: " project_number
    if [[ $project_number =~ ^[0-9]+$ ]]; then
        if (( $project_number >= 1 && $project_number <= ${#projects[@]} )); then
            existing_project="${projects[$(($project_number-1))]}"
            sudo certbot certonly --nginx -d "${existing_project##*/}"

            # Levantar el servidor
            start_server
        else
            echo "Número de proyecto no válido."
        fi
    else
        echo "Por favor, ingrese un número válido."
    fi
}

# Función para clonar un nuevo proyecto y configurar SSL
clone_and_configure_project() {
    read -p "Indique la dirección del repositorio a clonar: " git_repo
    read -p "Indique el nombre de la carpeta del proyecto: " project_name
    read -p "Indique el nombre de la app principal de Django: " dj_app

    # Clonar el repositorio
    git -C /home/django clone $git_repo $project_name

    # Instalar dependencias
    pip install -q -r /home/django/$project_name/requirements.txt

    # Configurar certificado SSL
    read -p "Indique el nombre de dominio asociado al proyecto: " domain_name
    sudo certbot certonly --nginx -d $domain_name

    # Configurar Nginx
    sudo touch /etc/nginx/sites-available/$project_name
    sudo ln -s /etc/nginx/sites-available/$project_name /etc/nginx/sites-enabled/$project_name
    sudo rm /etc/nginx/sites-enabled/default

    # Configurar supervisor
    sudo touch /etc/supervisor/conf.d/$project_name.conf
    echo "[program:$project_name]" | sudo tee -a /etc/supervisor/conf.d/$project_name.conf
    echo "command=/home/django/.venv/bin/gunicorn_start" | sudo tee -a /etc/supervisor/conf.d/$project_name.conf
    echo "user=django" | sudo tee -a /etc/supervisor/conf.d/$project_name.conf
    echo "autostart=true" | sudo tee -a /etc/supervisor/conf.d/$project_name.conf
    echo "autorestart=true" | sudo tee -a /etc/supervisor/conf.d/$project_name.conf
    echo "redirect_stderr=true" | sudo tee -a /etc/supervisor/conf.d/$project_name.conf
    echo "stdout_logfile=/home/django/logs/$project_name-error.log" | sudo tee -a /etc/supervisor/conf.d/$project_name.conf

    # Levantar el servidor
    start_server
}

# Función principal
main() {
    print_title "INICIANDO SCRIPT"

    # Actualización e instalación de paquetes básicos
    print_title "INSTALANDO PAQUETES"
    sudo apt-get -qq update
    sudo apt-get -qq upgrade
    install_package "python3-dev"
    install_package "python3-pip"
    install_package "python3-venv"
    install_package "sqlite3"
    install_package "libsqlite3-dev"
    install_package "nginx"
    install_package "supervisor"
    install_package "certbot"
    install_package "python3-certbot-nginx"

    # Instalación de la última versión de Python
    print_title "INSTALANDO LA ÚLTIMA VERSIÓN DE PYTHON"
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt-get -qq update
    install_package "python3.11"

    # Configuración de Firewall
    print_title "CONFIGURANDO FIREWALL (ufw)"
    sudo ufw allow OpenSSH
    sudo ufw allow 'Nginx Full'
    sudo ufw --force enable

    # Configuración de SELinux (si está instalado)
    if command -v getenforce &>/dev/null; then
        print_subtitle "CONFIGURANDO SELINUX"
        sudo setsebool -P httpd_can_network_connect 1
    fi

    # Crear entorno virtual
    print_title "CREANDO ENTORNO VIRTUAL"
    virtualenv /home/django/.venv --python=python3

    # Obtener la opción del usuario
    get_user_option

    # Fin del script
    echo "=== FINALIZADO ==="
    echo "Por favor, asegúrese de migrar la base de datos y recopilar los archivos estáticos manualmente después de ejecutar este script."
}

# Llamar a la función principal
main
