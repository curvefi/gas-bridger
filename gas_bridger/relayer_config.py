import json
from pathlib import Path

DIR = Path(__file__).resolve().parent


class ChainMarketManager:
    @classmethod
    def get_file_name(cls) -> Path:
        return DIR / "deployments.json"

    @classmethod
    def load_config(cls) -> dict | None:
        filepath = cls.get_file_name()
        if not filepath.exists():
            return None

        with open(filepath, "r") as f:
            json_config = json.loads(f.read())
        return json_config

    @classmethod
    def update_config(cls, json_config: dict) -> None:
        with open(cls.get_file_name(), "w") as f:
            json.dump(json_config, f, indent=4)
            f.write("\n")
