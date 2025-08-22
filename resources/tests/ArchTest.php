<?php

declare(strict_types=1);

arch()->preset()->php();

arch()->preset()->strict();

arch()->preset()->security();

arch()->preset()->laravel();

arch('strict types')
    ->expect('App')
    ->toUseStrictTypes();

arch('avoid open for extension')
    ->expect('App')
    ->classes()
    ->toBeFinal();

arch('ensure no extends')
    ->expect('App')
    ->classes()
    ->not->toBeAbstract();

arch('avoid mutation')
    ->expect('App')
    ->classes()
    ->toBeReadonly()
    ->ignoring([
        'App\Console\Commands',
        'App\Exceptions',
        'App\Filament',
        'App\Http\Requests',
        'App\Jobs',
        'App\Livewire',
        'App\Mail',
        'App\Models',
        'App\Notifications',
        'App\Providers',
        'App\View',
    ]);

arch('avoid inheritance')
    ->expect('App')
    ->classes()
    ->toExtendNothing()
    ->ignoring([
        'App\Console\Commands',
        'App\Exceptions',
        'App\Filament',
        'App\Http\Requests',
        'App\Jobs',
        'App\Livewire',
        'App\Mail',
        'App\Models',
        'App\Notifications',
        'App\Providers',
        'App\View',
        'App\Services\Autocomplete\Types',
    ]);

arch('annotations')
    ->expect('App')
    ->toHavePropertiesDocumented()
    ->toHaveMethodsDocumented();

arch('it will not use debugging functions')
    ->expect(['dd', 'dump', 'ray', 'var_dump', 'print_r'])
    ->each->not->toBeUsed();

arch('nothing use env vars directly')
    ->expect('env')
    ->not->toBeUsed();

arch('models are classes')
    ->expect('App\Models')
    ->toBeClasses()
    ->ignoring('App\Models\Traits');

arch('model traits are traits')
    ->expect('App\Models\Traits')
    ->toBeTraits();

// arch('enums are enums')
//     ->expect('App\Enums')
//     ->toBeEnums()
//     ->ignoring(['App\Enums\Traits', 'App\Enums\Contracts']);

// arch('enums traits are traits')
//     ->expect('App\Enums\Traits')
//     ->toBeTraits();

// arch('enums contracts are interfaces')
//     ->expect('App\Enums\Contracts')
//     ->toBeInterface();
