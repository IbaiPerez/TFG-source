# Ejemplos Prácticos de Upgrades de Edificios

## Ejemplo 1: Mina de Oro Base → Especializaciones

### Edificio Base: "Mina de Oro"
```
name: Mina de Oro
gold_produced: 8
food_produced: 0
construction_cost: 80
required_natural_resource: Gold
```

### Especialización 1: "Mina de Oro Intensiva"
```
name: Mina de Oro Intensiva
gold_produced: 18
food_produced: 0
construction_cost: 150
```

### Especialización 2: "Mina de Oro con Asentamiento"
```
name: Mina de Oro con Asentamiento
gold_produced: 12
food_produced: 5
construction_cost: 140
```

### Opciones de Mejora del edificio base:
```
upgrade_options:
  - name: "Intensificar Producción"
    upgrade_type: GOLD
    description: "Maximiza la extracción de oro"
    target_building: Mina de Oro Intensiva
    additional_cost: 30
    gold_bonus: 10
    
  - name: "Agregar Asentamiento"
    upgrade_type: COMBINED
    description: "Añade población para sustento alimenticio"
    target_building: Mina de Oro con Asentamiento
    additional_cost: 20
    gold_bonus: 4
    food_bonus: 5
```

---

## Ejemplo 2: Granja Base → Especializaciones

### Edificio Base: "Granja"
```
name: Granja
gold_produced: 2
food_produced: 8
construction_cost: 60
```

### Especialización 1: "Granja de Trigo"
```
name: Granja de Trigo
gold_produced: 2
food_produced: 16
construction_cost: 120
```

### Especialización 2: "Granja Comercial"
```
name: Granja Comercial
gold_produced: 10
food_produced: 10
construction_cost: 130
```

### Opciones de Mejora:
```
upgrade_options:
  - name: "Especializar en Trigo"
    upgrade_type: FOOD
    description: "Cultiva solo trigo para máxima producción"
    target_building: Granja de Trigo
    additional_cost: 25
    gold_bonus: 0
    food_bonus: 8
    
  - name: "Mercado Agrícola"
    upgrade_type: COMBINED
    description: "Vende excedentes para oro"
    target_building: Granja Comercial
    additional_cost: 35
    gold_bonus: 8
    food_bonus: 2
```

---

## Ejemplo 3: Puerto Base → Especializaciones

### Edificio Base: "Puerto"
```
name: Puerto
gold_produced: 5
food_produced: 4
construction_cost: 100
required_natural_resource: Fish
```

### Especialización 1: "Puerto Pesquero"
```
name: Puerto Pesquero
gold_produced: 5
food_produced: 12
construction_cost: 160
```

### Especialización 2: "Puerto Comercial"
```
name: Puerto Comercial
gold_produced: 15
food_produced: 4
construction_cost: 180
```

### Opciones de Mejora:
```
upgrade_options:
  - name: "Enfatizar Pesca"
    upgrade_type: FOOD
    description: "Infraestructura para pesca intensiva"
    target_building: Puerto Pesquero
    additional_cost: 40
    gold_bonus: 0
    food_bonus: 8
    
  - name: "Centro Comercial"
    upgrade_type: GOLD
    description: "Centro de distribución marítima"
    target_building: Puerto Comercial
    additional_cost: 50
    gold_bonus: 10
    food_bonus: 0
```

---

## En el Editor Godot

Para cada edificio base:

1. Abre el recurso `.tres` del edificio
2. En el panel derecho, expande "Upgrade Options"
3. Haz clic en "Add Element" para cada specialización
4. Para cada elemento:
   - `name`: Nombre visible en UI
   - `upgrade_type`: Elige GOLD, FOOD o COMBINED
   - `description`: Describe qué hace
   - `target_building`: Asigna el edificio specializado
   - `additional_cost`: Costo extra de mejora
   - `gold_bonus`: Bonus de oro vs edificio base
   - `food_bonus`: Bonus de comida vs edificio base

## Notas de Balance

- `additional_cost` debe ser < cost(target) - cost(base)
- Los bonuses deben reflejar la especialización
- COMBINED upgrades deben recompensarse menos que especializaciones puras
- Considera el costo total comparado con construir nuevo edificio
