<?php

declare(strict_types=1);

namespace App\Enums;

use App\Enums\Concerns\HasModel;
use App\Enums\Concerns\HasRandomPicker;
use App\Enums\Concerns\SeedDb;
use Filament\Support\Colors\Color;

enum DrivingLicenseRenewalStatuses: int {
    /** @use HasModel<\App\Models\DrivingLicenseCategory> */
    use HasModel, HasRandomPicker, SeedDb;

    case PENDING_SUBMIT = 1;
    case PENDING_REVIEW = 2;
    case APPROVED = 3;
    case CHANGES_REQUESTED = 4;
    case REJECTED = 5;
    case COMPLETED = 6;

    private function dbMap(): array {
        return [
            'id' => $this->value,
            'name' => $this->name,
            'description' => $this->description(),
        ];
    }

    public function description(): string {
        return match ($this) {
            self::PENDING_SUBMIT => 'La richiesta è in attesa di essere compilata e inviata dall\'utente.',
            self::PENDING_REVIEW => 'La richiesta è in attesa di revisione da parte di un amministratore.',
            self::APPROVED => 'La richiesta è stata approvata, ma l\'iter di rinnovo è ancora in corso.',
            self::CHANGES_REQUESTED => 'La richiesta è stata revisionata, ma sono stati richiesti cambiamenti o correzioni a i dati.',
            self::REJECTED => 'La richiesta è stata revisionata e respinta, l\'iter di rinnovo non verrà iniziato.',
            self::COMPLETED => 'La richiesta è stata approvata e l\'iter di rinnovo concluso.',
        };
    }

    public function label(): string {
        return __(strtolower("enums.driving_license_renewal_statuses.{$this->name}"));
    }

    /**
     * @return array<int, string>
     */
    public function badgeColor(): array {
        return match ($this) {
            self::PENDING_SUBMIT => Color::Orange,
            self::PENDING_REVIEW => Color::Yellow,
            self::APPROVED => Color::Green,
            self::CHANGES_REQUESTED => Color::Purple,
            self::REJECTED => Color::Red,
            self::COMPLETED => Color::Sky,
        };
    }

    /**
     * @return array<value-of<self>, string>
     */
    public static function toSelectOptions(): array {
        return collect(self::cases())->mapWithKeys(fn (self $case) => [$case->value => $case->label()])->toArray();
    }
}
