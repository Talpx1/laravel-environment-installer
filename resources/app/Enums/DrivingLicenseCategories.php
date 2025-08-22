<?php

declare(strict_types=1);

namespace App\Enums;

use App\Enums\Concerns\HasModel;
use App\Enums\Concerns\HasRandomPicker;
use App\Enums\Concerns\SeedDb;

enum DrivingLicenseCategories: int {
    /** @use HasModel<\App\Models\DrivingLicenseCategory> */
    use HasModel, HasRandomPicker, SeedDb;

    case AM = 1;
    case A1 = 2;
    case A2 = 3;
    case A = 4;
    case B1 = 5;
    case B = 6;
    case BE = 7;
    case C1 = 8;
    case C1E = 9;
    case C = 10;
    case CE = 11;
    case D1 = 12;
    case D1E = 13;
    case D = 14;
    case DE = 15;

    private function dbMap(): array {
        return [
            'id' => $this->value,
            'code' => $this->name,
            'description' => $this->description(),
        ];
    }

    public function description(): string {
        return match ($this) {
            self::AM => 'È richiesta per la guida di ciclomotori a 2 o 3 ruote e di quadricicli leggeri (cilindrata minore o uguale a 50 cm 3 o potenza minore o uguale a 4 kW, velocità minore o uguale a 45 km/h, massa a vuoto minore o uguale a 350 kg, esclusa la massa delle batterie per i veicoli elettrici). Questa patente si può conseguire in Italia a partire da 14 anni, ma abilita alla guida su tutto il territorio UE e SEE dal compimento dei 16 anni, fatta salva la possibilità di altri Stati membri di riconoscere la validità nel proprio territorio di una patente AM rilasciata a 14 anni.',
            self::A1 => 'È richiesta per la guida di motocicli di cilindrata minore o uguale a 125 cm3, potenza minore o uguale a 11 kW e rapporto potenza/massa minore o uguale a 0,10 kW/kg, nonché di tricicli di potenza minore o uguale a 15 kW. Questa patente si può conseguire a partire da 16 anni. Inoltre abilita a guidare tutti i veicoli di categoria AM.',
            self::A2 => 'È richiesta per la guida di motocicli di potenza minore o uguale a 35 kW e rapporto potenza/massa minore o uguale a 0,20 kW/kg, tali che non derivino da una versione che sviluppi più del doppio della potenza massima consentita, nonché di tricicli di potenza minore o uguale a 15 kW. Questa patente si può conseguire a partire da 18 anni. Inoltre abilita a guidare tutti i veicoli di categoria AM e A1.',
            self::A => 'È richiesta per la guida di motocicli senza limitazioni, nonché di tricicli di potenza superiore a 15 kW, a condizione che il titolare abbia compiuto 21 anni. Questa patente si può conseguire con accesso graduale a partire da 20 anni, a condizione di essere titolare di patente di cat. A2 da almeno 2 anni, oppure con accesso diretto a partire da 24 anni. In ogni caso occorrerà superare una prova pratica di guida su veicolo della categoria corrispondente. Inoltre abilita a guidare tutti i veicoli di categoria AM, A1 e A2.',
            self::B1 => 'È richiesta per la guida dei quadricicli diversi da quelli leggeri (massa a vuoto minore o uguale a 400 kg o 550 kg se per trasporto cose, esclusa la massa delle batterie per i veicoli elettrici e potenza nominale netta minore o uguale a 15 kW). Questa patente si può conseguire a partire da 16 anni e non abilita alla guida di alcun motociclo. Inoltre abilita a guidare tutti i veicoli di categoria AM.',
            self::B => 'È richiesta per la guida di autovetture (numero di posti minore o uguale a 9 e massa massima autorizzata minore o uguale a 3500 kg). Questa patente si può conseguire a partire da 18 anni. Con la patente B è possibile guidare anche un complesso di veicoli composto da motrice di categoria B e: rimorchio con massa massima autorizzata minore o uguale a 750 kg, oppure rimorchio con massa massima autorizzata superiore a 750 kg, purché la massa massima autorizzata del complesso sia minore o uguale a 3500 kg; rimorchio con massa massima autorizzata è superiore a 750 kg a condizione che la massa massima autorizzata del complesso sia superiore a 3500 kg, ma non a 4250 Kg. In tal caso occorre superare una prova pratica di guida, su veicolo specifico, all\'esito della quale è apposto sulla patente il codice 96. Inoltre abilita a guidare in ambito UE e SEE tutti i veicoli di categoria AM e B1; solo in Italia, veicoli di categoria A1 e, al compimento dei 21 anni di età, tricicli con potenza superiore a 15 kW.',
            self::BE => 'È richiesta per la guida di complessi di veicoli composti da motrice di categoria B e rimorchio con massa massima autorizzata superiore a 750 kg ma minore o uguale a 3500 kg: ne deriva che la massa massima autorizzata del complesso è minore o uguale a 7000 kg. Questa patente si può conseguire a partire da 18 anni. Inoltre abilita a guidare in ambito UE e SEE tutti i veicoli di categoria AM, B1 e B; solo in Italia, veicoli di categoria A1 e, al compimento dei 21 anni di età, tricicli con potenza superiore a 15 kW.',
            self::C1 => 'È richiesta per la guida di autocarri aventi massa massima autorizzata superiore a 3500 kg ma minore o uguale a 7500 kg, anche se trainanti un rimorchio con massa massima autorizzata minore o uguale a 750 kg. Questa patente si può conseguire a partire da 18 anni. Inoltre abilita a guidare in ambito UE e SEE tutti i veicoli di categoria AM, B1 e B; solo in Italia, veicoli di categoria A1 e, al compimento dei 21 anni di età, tricicli con potenza superiore a 15 kW',
            self::C1E => 'È richiesta per la guida di complessi di veicoli composti da: motrice di categoria C1 e rimorchio con massa massima autorizzata superiore a 750 kg, purché la massa massima autorizzata del complesso sia minore o uguale a 12000 kg; motrice di categoria B e rimorchio con massa massima autorizzata superiore a 3500 kg, purché la massa massima autorizzata del complesso sia minore o uguale a 12000 kg. Questa patente si può conseguire a partire da 18 anni. Inoltre abilita a guidare in ambito UE e SEE tutti i veicoli di categoria AM, B1, B, BE e C1; solo in Italia, veicoli di categoria A1 e, al compimento dei 21 anni di età, tricicli con potenza superiore a 15 kW.',
            self::C => 'È richiesta per la guida di autocarri aventi massa massima autorizzata superiore a 3500 kg, anche se trainanti un rimorchio con massa massima autorizzata minore o uguale a 750 kg. Questa patente si può conseguire a partire da 21 anni, fatta salva l\'ipotesi che il candidato sia titolare di CQC per il trasporto di cose: in tal caso, il requisito anagrafico minimo è di 18. Inoltre abilita a guidare in ambito UE e SEE tutti i veicoli di categoria AM, B1, B e C1; solo in Italia, veicoli di categoria A1 e, al compimento dei 21 anni di età, tricicli con potenza superiore a 15 kW.',
            self::CE => 'È richiesta per la guida di complessi di veicoli composti da motrice di categoria C e rimorchio con massa massima autorizzata superiore a 750 kg. Questa patente si può conseguire a partire da 21 anni, fatta salva l\'ipotesi che il candidato sia titolare di CQC per il trasporto di cose: in tal caso, il requisito anagrafico minimo è di 18 anni. Inoltre abilita a guidare in ambito UE e SEE tutti i veicoli di categoria AM, B1, B, BE, C1, C1E e C; solo in Italia, veicoli di categoria A1 e, al compimento dei 21 anni di età, tricicli con potenza superiore a 15 kW.',
            self::D1 => 'È richiesta per la guida di autoveicoli con numero di posti minore o uguale a 17 e lunghezza minore o uguale a 8 metri, anche se trainanti un rimorchio con massa massima autorizzata minore o uguale a 750 kg. Questa patente si può conseguire a partire da 21 anni. Inoltre abilita a guidare in ambito UE e SEE tutti i veicoli di categoria AM, B1e B; solo in Italia, veicoli di categoria A1 e tricicli con potenza superiore a 15 kW.',
            self::D1E => 'È richiesta per la guida di complessi di veicoli composti da motrice di categoria D1 e rimorchio con massa massima autorizzata superiore a 750 kg. Questa patente si può conseguire a partire da 21 anni. noltre posso guidare in ambito UE e SEE tutti i veicoli di categoria AM, B1, B, BE e D1; solo in Italia, veicoli di categoria A1 e tricicli con potenza superiore a 15 kW.',
            self::D => 'È richiesta per la guida di autoveicoli con numero di posti superiore a 9, anche se trainanti un rimorchio con massa massima autorizzata minore o uguale a 750 kg. Questa patente si può conseguire a partire da 24 anni, fatta salva l\'ipotesi che il candidato sia titolare di CQC per il trasporto di persone: in tal caso, il requisito anagrafico minimo è di 21 anni. Inoltre abilita a guidare in ambito UE e SEE tutti i veicoli di categoria AM, B1, B e D1; solo in Italia, veicoli di categoria A1 e tricicli con potenza superiore a 15 kW.',
            self::DE => 'È richiesta per la guida di complessi di veicoli composti da motrice di categoria D e rimorchio con massa massima autorizzata superiore a 750 kg. Questa patente si può conseguire a partire da 24 anni, fatta salva l\'ipotesi che il candidato sia titolare di CQC per il trasporto di persone: in tal caso, il requisito anagrafico minimo è di 21 anni. Inoltre abilita a guidare in ambito UE e SEE tutti i veicoli di categoria AM, B1, B, BE, D1, D1E e D; solo in Italia, veicoli di categoria A1 e tricicli con potenza superiore a 15 kW.',
        };
    }
}
