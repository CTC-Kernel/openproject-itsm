# frozen_string_literal: true

$:.push File.expand_path("lib", __dir__)

require "open_project/itsm/version"

Gem::Specification.new do |s|
  s.name        = "openproject-itsm"
  s.version     = OpenProject::Itsm::VERSION
  s.authors     = ["Cyber Threat Consulting"]
  s.email       = ["thibault.llopis@cyber-threat-consulting.com"]
  s.summary     = "OpenProject ITSM — gestion des incidents et demandes de service"
  s.description = "Module ITSM complet pour OpenProject : incidents, demandes de service, " \
                  "matrice de priorité impact/urgence, SLA en heures ouvrées, tableaux de bord " \
                  "infogérance multi-clients, portail demandeur et création de tickets par email."
  s.license     = "GPL-3.0"
  s.homepage    = "https://cyber-threat-consulting.com"

  s.required_ruby_version = ">= 3.2"

  s.files = Dir["{app,config,db,lib,docs}/**/*", "README.md"]
end
