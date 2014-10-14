{% set cfg = opts['ms_project'] %}
{% set scfg = salt['mc_utils.json_dump'](cfg)%}
{% set php = salt['mc_php.settings']() %}
{% set data = cfg.data %}
{% set pma_ver=data.pma_ver %}

{% set rpw = salt['mc_mysql.settings']().root_passwd %}

prepreqs-{{cfg.name}}:
  pkg.installed:
    - pkgs:
      - unzip
      - xsltproc
      - curl
      - {{ php.packages.mysql }}
      - {{ php.packages.gd }}
      - {{ php.packages.cli }}
      - {{ php.packages.curl }}
      - {{ php.packages.ldap }}
      - {{ php.packages.dev }}
      - {{ php.packages.json }}
      - sqlite3
      - libsqlite3-dev
      - mysql-client
      - apache2-utils
      - autoconf
      - automake
      - build-essential
      - bzip2
      - gettext
      - git
      - groff
      - libbz2-dev
      - libcurl4-openssl-dev
      - libdb-dev
      - libgdbm-dev
      - libreadline-dev
      - libfreetype6-dev
      - libsigc++-2.0-dev
      - libsqlite0-dev
      - libsqlite3-dev
      - libtiff5
      - libtiff5-dev
      - libwebp5
      - libwebp-dev
      - libssl-dev
      - libtool
      - libxml2-dev
      - libxslt1-dev
      - libopenjpeg-dev
      - libopenjpeg2
      - m4
      - man-db
      - pkg-config
      - poppler-utils
      - python-dev
      - python-imaging
      - python-setuptools
      - zlib1g-dev

{{cfg.name}}-pmadownload:
  cmd.run:
    - user: {{cfg.user}}
    - cwd: {{ cfg.project_root}}
    - onlyif: test ! -e {{cfg.project_root}}/phpMyAdmin-{{pma_ver}}-all-languages 
    - name: >
            wget -c "http://downloads.sourceforge.net/project/phpmyadmin/phpMyAdmin/{{pma_ver}}/phpMyAdmin-{{pma_ver}}-all-languages.zip?r=http%3A%2F%2Fwww.phpmyadmin.net%2Fhome_page%2Findex.php&ts=1413296402&use_mirror=freefr" -O pma.zip&&
            unzip pma.zip && ln -s $PWD/phpMyAdmin-{{pma_ver}}-all-languages www

{{cfg.name}}-htaccess:
  file.managed:
    - name: {{data.htaccess}}
    - source: ''
    - user: www-data
    - group: www-data
    - mode: 770

{% if data.get('http_users', {}) %}
{% for userrow in data.http_users %}
{% for user, passwd in userrow.items() %}
{{cfg.name}}-{{user}}-htaccess:
  webutil.user_exists:
    - name: {{user}}
    - password: {{passwd}}
    - htpasswd_file: {{data.htaccess}}
    - options: m
    - force: true
    - watch:
      - file: {{cfg.name}}-htaccess
{% endfor %}
{% endfor %}
{% endif %}  

{{cfg.name}}-dirs:
  file.directory:
    - makedirs: true
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - mode: 770
    - watch:
      - pkg: prepreqs-{{cfg.name}}
    - names:
      - {{cfg.project_root}}/lib
      - {{cfg.project_root}}/bin
      - {{cfg.project_root}}/www
      - {{cfg.data_root}}/var
      - {{cfg.data_root}}/var/log
      - {{cfg.data_root}}/var/tmp
      - {{cfg.data_root}}/var/run
      - {{cfg.data_root}}/var/private

{{cfg.name}}-pma-sym:
  file.symlink:
    - target: {{cfg.project_root}}/phpMyAdmin-{{pma_ver}}-all-languages
    - name: {{cfg.project_root}}/www
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - watch:
      - file: {{cfg.name}}-dirs

{% for d in ['lib', 'bin', 'www'] %}
{{cfg.name}}-dirs{{d}}:
  file.symlink:
    - target: {{cfg.project_root}}/{{d}}
    - name: {{cfg.data_root}}/{{d}}
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - watch:
      - file: {{cfg.name}}-dirs
{% endfor %}

{% for d in ['var'] %}
{{cfg.name}}-l-dirs{{d}}:
  file.symlink:
    - name: {{cfg.project_root}}/{{d}}
    - target: {{cfg.data_root}}/{{d}}
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - watch:
      - file: {{cfg.name}}-dirs
{% endfor %}

{% for d in ['log', 'private', 'tmp'] %}
{{cfg.name}}-l-var-dirs{{d}}:
  file.symlink:
    - name: {{cfg.project_root}}/{{d}}
    - target: {{cfg.data_root}}/var/{{d}}
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - watch:
      - file: {{cfg.name}}-dirs
{% endfor %}
{% for i in ['config.inc.php'] %}
config-{{i}}:
  file.managed:
    - source: salt://makina-projects/{{cfg.name}}/files/{{i}}
    - name: {{cfg.project_root}}/www/{{i}}
    - template: jinja
    - mode: 750
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - defaults:
        cfg: |
             {{scfg}}
    - require:
      - cmd: {{cfg.name}}-pmadownload
{% endfor %}

loadtables:
  cmd.run:
    - name: mysql -u phpmyadmin --password="{{salt['mc_utils.generate_stored_password'](cfg.name+'.pmauser')}}"< {{cfg.project_root}}/www/examples/create_tables.sql
    - require:
      - cmd: {{cfg.name}}-pmadownload


