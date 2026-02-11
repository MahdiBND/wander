# Project Structure
  this foldering pattern should always be followed

<AppName>/
    ├── App/
    ├── Shared/
    │   ├── Extensions/
    │   ├── Components/
    │   ├── Models/
    │   ├── Modifiers/
    │   ├── Protocols/
    │   ├── Service/
    │   └── Utils/
    │
    ├── Services/
    │   ├── Network/
    │   └── DataSource/
    │
    ├── Features/
    │   ├── <FeatureName>/
    │   │   ├── Components/
    │   │   ├── Models/
    │   │   ├── Service/
    │   │   ├── Store/
    │   │   ├── Protocols/
    │   │   └── View/
    │   └── ...
    │
    └── Resources/

