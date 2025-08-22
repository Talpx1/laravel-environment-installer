<?php

declare(strict_types=1);

namespace App\Enums\Concerns;

trait HasRandomPicker {
    /**
     * Returns a random case of the enum
     */
    public static function random(): static {
        return static::cases()[array_rand(static::cases())];
    }
}
