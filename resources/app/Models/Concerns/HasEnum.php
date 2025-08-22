<?php

declare(strict_types=1);

namespace App\Models\Concerns;

use BackedEnum;
use Illuminate\Support\Str;

/**
 * @template TEnum of BackedEnum
 */
trait HasEnum {
    /**
     * @return class-string<BackedEnum>
     */
    private static function guessEnumClass(): string {
        return 'App\\Enums\\'.Str::plural(class_basename(__CLASS__));
    }

    /** @return class-string<BackedEnum> */
    private static function getOrGuessEnumClass(): string {
        if (method_exists(static::class, 'getEnumClass')) {
            return static::getEnumClass();
        }

        /** @var class-string<BackedEnum> */
        $enum = static::guessEnumClass();

        if (! class_exists($enum)) {
            throw new \Exception('Enum for model '.__CLASS__." could not be guessed ({$enum} enum does not exist). Manually specify the enum via the getEnumClass static method.");
        }

        return $enum;
    }

    /**
     * @return TEnum
     */
    public function enumCase(): BackedEnum {
        $class = static::getOrGuessEnumClass();

        return $class::tryFrom($this->getKey());
    }
}
