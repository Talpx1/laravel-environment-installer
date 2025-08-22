<?php

declare(strict_types=1);

namespace App\Enums\Concerns;

use Illuminate\Support\Facades\DB;

trait SeedDb {
    private static function guessTable(): string {
        if (method_exists(static::class, 'getOrGuessModelClass')) {
            $class = static::getOrGuessModelClass();

            return (new $class)->getTable();
        }

        return str(class_basename(__CLASS__))->snake()->lower()->toString();
    }

    /**
     * @param  static[]  $cases
     */
    public static function seed(array $cases): void {
        DB::table(static::$table ?? self::guessTable())->insert(array_map(fn (self $case) => $case->dbMap(), $cases));
    }

    /**
     * @return array<string, mixed>
     */
    abstract private function dbMap(): array;
}
