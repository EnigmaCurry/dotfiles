{% set user=pillar['user'] %}

Symlink arch-quickstart to our home git dir:
  file.symlink:
    - name: /home/{{user}}/git/arch-quickstart
    - user: {{user}}
    - group: root
    - target: /opt/arch-quickstart
    - makedirs: True

