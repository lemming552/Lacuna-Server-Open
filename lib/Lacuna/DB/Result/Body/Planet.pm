package Lacuna::DB::Result::Body::Planet;

use Moose;
extends 'Lacuna::DB::Result::Body';
use Lacuna::Constants qw(FOOD_TYPES ORE_TYPES);
use List::Util qw(shuffle);
use Lacuna::Util qw(to_seconds randint);
use DateTime;
no warnings 'uninitialized';

sub ships_travelling { 
    my ($self, $where, $reverse) = @_;
    my $order = '-asc';
    if ($reverse) {
        $order = '-desc';
    }
    $where->{body_id} = $self->id;
    return Lacuna->db->resultset('Lacuna::DB::Result::Ships')->search(
        $where,
        {
            order_by    => { $order => 'date_available' },
        }
    );
}

# FREEBIES
sub get_freebie {
    my ($self, $class) = @_;
    return $self->freebies->{$class} || 0;
}

sub add_freebie {
    my ($self, $class, $level) = @_;
    my $freebies = $self->freebies;
    if (scalar(keys %{$freebies}) >= 10 && ! exists $freebies->{$class}) {
        my ($key) = keys %{$freebies};
        delete $freebies->{key};
    }
    $freebies->{$class} = $level;
    $self->freebies($freebies);
    return $self;
}

sub spend_freebie {
    my ($self, $class) = @_;
    my $freebies = $self->freebies;
    delete $freebies->{$class};
    $self->freebies($freebies);
    return $self;
}

sub sanitize {
    my ($self) = @_;
    my $buildings = $self->buildings->search({class => { 'not like' => 'Lacuna::DB::Result::Building::Permanent%' } });
    foreach my $building ($buildings->next) {
        $building->delete;    
    }
    my @attributes = qw(    building_count happiness_hour happiness waste_hour waste_stored waste_capacity
        energy_hour energy_stored energy_capacity water_hour water_stored water_capacity ore_capacity
        rutile_stored chromite_stored chalcopyrite_stored galena_stored gold_stored uraninite_stored bauxite_stored
        goethite_stored halite_stored gypsum_stored trona_stored kerogen_stored methane_stored anthracite_stored
        sulfur_stored zircon_stored monazite_stored fluorite_stored beryl_stored magnetite_stored ore_hour
        food_capacity food_consumption_hour lapis_production_hour potato_production_hour apple_production_hour
        root_production_hour corn_production_hour cider_production_hour wheat_production_hour bread_production_hour
        soup_production_hour chip_production_hour pie_production_hour pancake_production_hour milk_production_hour
        meal_production_hour algae_production_hour syrup_production_hour fungus_production_hour burger_production_hour
        shake_production_hour beetle_production_hour lapis_stored potato_stored apple_stored root_stored corn_stored
        cider_stored wheat_stored bread_stored soup_stored chip_stored pie_stored pancake_stored milk_stored meal_stored
        algae_stored syrup_stored fungus_stored burger_stored shake_stored beetle_stored bean_production_hour bean_stored
    );
    Lacuna->db->resultset('Lacuna::DB::Result::Ships')->search({foreign_body_id => $self->id})->delete_all;
    Lacuna->db->resultset('Lacuna::DB::Result::Ships')->search({body_id => $self->id})->delete_all;
    foreach my $attribute (@attributes) {
        $self->$attribute(0);
    }
    $self->empire_id(undef);
    if ($self->get_type eq 'habitable planet') {
        $self->usable_as_starter(randint(1,9999));
    }
    $self->update;
}

around 'get_status' => sub {
    my ($orig, $self, $empire) = @_;
    my $out = $orig->($self);
    my %ore;
    foreach my $type (ORE_TYPES) {
        $ore{$type} = $self->$type();
    }
    $out->{size}            = $self->size;
    $out->{ore}             = \%ore;
    $out->{water}           = $self->water;
    if (defined $empire) {
        if ($self->empire_id eq $empire->id) {
            $out->{alignment} = 'self';
        }
        elsif ($self->empire_id ne 'None') {
            $out->{alignment} = 'hostile';
        }
    }
    if (defined $empire && $empire->id eq $self->empire_id) {
        $self->tick;
        $out->{building_count}  = $self->building_count;
        $out->{water_capacity}  = $self->water_capacity;
        $out->{water_stored}    = $self->water_stored;
        $out->{water_hour}      = $self->water_hour;
        $out->{energy_capacity} = $self->energy_capacity;
        $out->{energy_stored}   = $self->energy_stored;
        $out->{energy_hour}     = $self->energy_hour;
        $out->{food_capacity}   = $self->food_capacity;
        $out->{food_stored}     = $self->food_stored;
        $out->{food_hour}       = $self->food_hour;
        $out->{ore_capacity}    = $self->ore_capacity;
        $out->{ore_stored}      = $self->ore_stored;
        $out->{ore_hour}        = $self->ore_hour;
        $out->{waste_capacity}  = $self->waste_capacity;
        $out->{waste_stored}    = $self->waste_stored;
        $out->{waste_hour}      = $self->waste_hour;
        $out->{happiness}       = $self->happiness;
        $out->{happiness_hour}  = $self->happiness_hour;
    }
    return $out;
};

# resource concentrations
use constant rutile => 1;

use constant chromite => 1;

use constant chalcopyrite => 1;

use constant galena => 1;

use constant gold => 1;

use constant uraninite => 1;

use constant bauxite => 1;

use constant goethite => 1;

use constant halite => 1;

use constant gypsum => 1;

use constant trona => 1;

use constant kerogen => 1;

use constant methane => 1;

use constant anthracite => 1;

use constant sulfur => 1;

use constant zircon => 1;

use constant monazite => 1;

use constant fluorite => 1;

use constant beryl => 1;

use constant magnetite => 1;

use constant water => 0;


# BUILDINGS

sub get_buildings_of_class {
    my ($self, $class) = @_;
    return Lacuna->db->resultset('Lacuna::DB::Result::Building')->search(
        {
            body_id => $self->id,
            class   => $class,
        },
        {
            order_by    => { -desc => 'level' },
        }
    );
}

sub get_building_of_class {
    my ($self, $class) = @_;
    my $building = Lacuna->db->resultset('Lacuna::DB::Result::Building')->search(
        {
            body_id => $self->id,
            class   => $class,
        },
        {
            order_by    => { -desc => 'level' },
        }
    )->single;
    $building->body($self);
    return $building;
}

has command => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $building = $self->get_building_of_class('Lacuna::DB::Result::Building::PlanetaryCommand');
        return undef unless defined $building;
        $building->body($self);
        return $building;
    },
);

has mining_ministry => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $building = $self->get_building_of_class('Lacuna::DB::Result::Building::Ore::Ministry');
        return undef unless defined $building;
        $building->body($self);
        return $building;
    },
);

has network19 => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $building = $self->get_building_of_class('Lacuna::DB::Result::Building::Network19');
        return undef unless defined $building;
        $building->body($self);
        return $building;
    },
);

has refinery => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $building = $self->get_building_of_class('Lacuna::DB::Result::Building::Ore::Refinery');
        return undef unless defined $building;
        $building->body($self);
        return $building;
    },
);

has spaceport => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $building = $self->get_building_of_class('Lacuna::DB::Result::Building::SpacePort');
        return undef unless defined $building;
        $building->body($self);
        return $building;
    },
);    

sub is_space_free {
    my ($self, $x, $y) = @_;
    my $count = $self->buildings->search({x=>$y, y=>$y})->count;
    return 0 if $count > 0;
    return 1;
}

sub check_for_available_build_space {
    my ($self, $x, $y) = @_;
    if ($x > 5 || $x < -5 || $y > 5 || $y < -5) {
        confess [1009, "That's not a valid space for a building.", [$x, $y]];
    }
    if ($self->building_count >= $self->size) {
        confess [1009, "You've already reached the maximum number of buildings for this planet.", $self->size];
    }
    unless ($self->is_space_free($x, $y)) {
        confess [1009, "That space is already occupied.", [$x,$y]]; 
    }
    return 1;
}

sub has_met_building_prereqs {
    my ($self, $building, $cost) = @_;
    $building->check_build_prereqs($self);
    $self->has_resources_to_build($building, $cost);
    $self->has_max_instances_of_building($building);
    $self->has_resources_to_operate($building);
    return 1;
}

sub can_build_building {
    my ($self, $building) = @_;
    $self->check_for_available_build_space($building->x, $building->y);
    $self->tick;
    $self->has_room_in_build_queue;
    $self->has_met_building_prereqs($building);
    return $self;
}

sub has_room_in_build_queue {
    my ($self) = shift;
    my $max = 1;
    my $dev_ministry = $self->get_building_of_class('Lacuna::DB::Result::Building::Development');
    if (defined $dev_ministry) {
        $max += $dev_ministry->level;
    }
    my $count = $self->builds->count;
    if ($count >= $max) {
        confess [1009, "There's no room left in the build queue.", $max];
    }
    return 1; 
}

use constant operating_resource_names => qw(food_hour energy_hour ore_hour water_hour waste_hour);

has future_operating_resources => (
    is      => 'rw',
    clearer => 'clear_future_operating_resources',
    lazy    => 1,
    default => sub {
        my $self = shift;
        
        # get current
        my %future;
        foreach my $method ($self->operating_resource_names) {
            $future{$method} = $self->$method;
        }
        
        # adjust for what's already in build queue
        my $queued_builds = $self->builds;
        while (my $build = $queued_builds->next) {
            $build->body($self);
            my $other = $build->stats_after_upgrade;
            foreach my $method ($self->operating_resource_names) {
                $future{$method} += $other->{$method} - $build->$method;
            }
        }
        return \%future;
    },
);

sub has_resources_to_operate {
    my ($self, $building, $queued_builds) = @_;
    
    # get future
    my $future = $self->future_operating_resources;
    
    # get change for this building
    my $after = $building->stats_after_upgrade;

    # check our ability to sustain ourselves
    foreach my $method ($self->operating_resource_names) {
        my $delta = $after->{$method} - $building->$method;
        # don't allow it if it sucks resources && its sucking more than we're producing
        if ($delta < 0 && $future->{$method} + $delta < 0) {
            my $resource = $method;
            $resource =~ s/(\w+)_hour/$1/;
            confess [1012, "Unsustainable. Not enough resources being produced to build this.", $resource];
        }
    }
    return 1;
}

sub has_resources_to_build {
    my ($self, $building, $cost) = @_;
    $cost ||= $building->cost_to_upgrade;
    foreach my $resource (qw(food energy ore water)) {
        my $stored = $resource.'_stored';
        unless ($self->$stored >= $cost->{$resource}) {
            confess [1011, "Not enough resources in storage to build this.", $resource];
        }
    }
    return 1;
}

sub has_max_instances_of_building {
    my ($self, $building) = @_;
    return 0 if $building->max_instances_per_planet == 9999999;
    my $count = $self->get_buildings_of_class($building->class)->count;
    if ($count >= $building->max_instances_per_planet) {
        confess [1009, sprintf("You are only allowed %s of these buildings per planet.",$building->max_instances_per_planet), [$building->max_instances_per_planet, $count]];
    }
}

sub builds { 
    my ($self, $reverse) = @_;
    my $order = '-asc';
    if ($reverse) {
        $order = '-desc';
    }
    return Lacuna->db->resultset('Lacuna::DB::Result::Building')->search(
        { body_id => $self->id, is_upgrading => 1 },       
        { $order => 'upgrade_ends' }
    );
}

has last_in_build_queue => (
    is      => 'ro',
    clearer => 'clear_last_in_build_queue',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $building = $self->builds(1)->next;
        return undef unless defined $building;
        $building->body($self);
        return $building;
    }
);

sub get_existing_build_queue_time {
    my $self = shift;
    my $time_to_build = DateTime->now;
    my $last_in_queue = $self->last_in_build_queue;
    if (defined $last_in_queue) {
        $time_to_build = $last_in_queue->date_complete;    
    }
    return $time_to_build;
}

sub lock_plot {
    my ($self, $x, $y) = @_;
    return Lacuna->cache->set('plot_contention_lock', $self->id.'|'.$x.'|'.$y,{locked=>1}, 30); # lock it
}

sub is_plot_locked {
    my ($self, $x, $y) = @_;
    return eval{Lacuna->cache->get('plot_contention_lock', $self->id.'|'.$x.'|'.$y)->{locked}};
}

sub build_building {
    my ($self, $building) = @_;
    
    $self->building_count($self->building_count + 1);
    $self->update;

    $building->date_created(DateTime->now);
    $building->body_id($self->id);
    $building->body($self);
    $building->upgrade_started(DateTime->now);
    $building->is_upgrading(1);
    $building->level(0) unless $building->level;

    # set time to build, plus what's in the queue
    my $time_to_build = $self->get_existing_build_queue_time->add(seconds=>$building->time_to_build);
    $building->upgrade_ends($time_to_build);
    $building->insert;
}

sub found_colony {
    my ($self, $empire) = @_;
    $self->empire_id($empire->id);
    $self->empire($empire);
    $self->usable_as_starter(0);
    $self->last_tick(DateTime->now);
    $self->update;    

    # award medal
    my $type = ref $self;
    $type =~ s/^.*::(\w\d+)$/$1/;
    $empire->add_medal($type);

    # add command building
    my $command = Lacuna->db->resultset('Lacuna::DB::Result::Building')->new({
        x               => 0,
        y               => 0,
        class           => 'Lacuna::DB::Result::Building::PlanetaryCommand',
        level           => $empire->species->growth_affinity - 1,
    });
    $self->build_building($command);
    $command->finish_upgrade;
    
    # add starting resources
    $self->tick;
    $self->add_algae(700);
    $self->add_energy(700);
    $self->add_water(700);
    $self->add_ore(700);
    $self->update;
    
    # newsworthy
    $self->add_news(75,'%s founded a new colony on %s.', $empire->name, $self->name);
        
    return $self;
}

sub recalc_stats {
    my ($self) = @_;
    my %stats = ( needs_recalc => 0 );
    my $buildings = $self->buildings;
    while (my $building = $buildings->next) {
        $stats{waste_capacity} += $building->waste_capacity;
        $stats{water_capacity} += $building->water_capacity;
        $stats{energy_capacity} += $building->energy_capacity;
        $stats{food_capacity} += $building->food_capacity;
        $stats{ore_capacity} += $building->ore_capacity;
        $stats{happiness_hour} += $building->happiness_hour;
        $stats{waste_hour} += $building->waste_hour;               
        $stats{energy_hour} += $building->energy_hour;
        $stats{water_hour} += $building->water_hour;
        $stats{ore_hour} += $building->ore_hour;
        $stats{food_consumption_hour} += $building->food_consumption_hour;
        foreach my $type (FOOD_TYPES) {
            my $method = $type.'_production_hour';
            $stats{$method} += $building->$method();
        }
        if ($building->isa('Lacuna::DB::Result::Building::Ore::Ministry')) {
            foreach my $type (ORE_TYPES) {
                my $method = $type.'_hour';
                $stats{$method} += $building->$method();
            }
        }
    }
    foreach my $type (ORE_TYPES) {
        my $method = $type.'_hour';
        $stats{$method} += sprintf('%.0f',$self->$type * $stats{ore_hour} / 10000);
    }
    $self->update(\%stats);
    return $self;
}

# NEWS

sub restrict_coverage_delta_in_seconds {
    my $self = shift;
    return to_seconds(DateTime->now - $self->restrict_coverage_delta);
}

sub add_news {
    my $self = shift;
    my $chance = shift;
    my $headline = shift;
    if ($self->restrict_coverage) {
        my $network19 = $self->network19;
        if (defined $network19) {
            $chance += $network19->level * 2;
            $chance = $chance / $self->command->level; 
        }
    }
    if (randint(1,100) <= $chance) {
        $headline = sprintf $headline, @_;
        Lacuna->db->resultset('Lacuna::DB::Result::News')->new({
            date_posted => DateTime->now,
            zone        => $self->zone,
            headline    => $headline,
        })->insert;
        return 1;
    }
    return 0;
}


# RESOURCE MANGEMENT

sub tick {
    my ($self) = @_;
    my $now = DateTime->now;
    my %todo;
    my $i; # in case 2 things finish at exactly the same time

    # get building tasks
    my $buildings = Lacuna->db->resultset('Lacuna::DB::Result::Building')->search({
        body_id     => $self->id,
        -or         => [
            -and    => [
                is_upgrading    => 1,
                upgrade_ends    => {'<=' => $now},
            ],
            -and    => [
                is_working      => 1,
                work_ends       => {'<=' => $now},
            ],
        ],
    });
    while (my $building = $buildings->next) {
        if ($building->is_upgrading && $building->upgrade_ends <= $now) {
            $todo{format_date($building->upgrade_ends).$i} = {
                object  => $building,
                type    => 'building upgraded',
            };
        }
        if ($building->is_working && $building->work_ends <= $now) {
            $todo{format_date($building->work_ends).$i} = {
                object  => $building,
                type    => 'building work complete',
            };
        }
        $i++;
    }

    # get ship tasks
    my $ships = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->search({
        body_id         => $self->id,
        date_available  => { '<=' => $now },
        task            => { '!=' => 'Docked' },
    });
    while (my $ship = $ships->next ) {
        if ($ship->task eq 'Travelling') {
            $todo{format_date($ship->date_available).$i} = {
                object  => $ship,
                type    => 'ship arrives',
            };
        }
        elsif ($ship->task eq 'Building') {
            $todo{format_date($ship->date_available).$i} = {
                object  => $ship,
                type    => 'ship built',
            };
        }
        $i++;
    }
    
    # synchronize completion of tasks
    foreach my $key (sort keys %todo) {
        my ($object, $job) = ($todo{$key}{object}, $todo{$key}{type});
        $object->body($self);
        if ($job eq 'ship built') {
            $self->tick_to($object->date_available);
            $object->finish_construction;
        }
        elsif ($job eq 'ship arrives') {
            $self->tick_to($object->date_available);
            $object->arrive;            
        }
        elsif ($job eq 'building work complete') {
            $self->tick_to($object->work_ends);
            $object->finish_work;
        }
        elsif ($job eq 'building upgraded') {
            $self->tick_to($object->upgrade_ends);
            $object->finish_upgrade;
        }
    }
    
    # check / clear boosts
    if ($self->boost_enabled) {
        my $empire = $self->empire;
        my $still_enabled = 0;
        foreach my $resource (qw(energy water ore happiness food)) {
            my $boost = $resource.'_boost';
            if ($now > $empire->$boost) {
                $self->needs_recalc(1);
            }
            else {
                $still_enabled = 1;
            }
        }
        unless ($still_enabled) {
            $self->boost_enabled(0);
        }
    }

    $self->tick_to($now);

    # clear caches
    $self->clear_future_operating_resources;
    
}

sub tick_to {
    my ($self, $now) = @_;
    my $interval = $now - $self->last_tick;
    my $seconds = to_seconds($interval);
    my $tick_rate = $seconds / 3600;
    $self->last_tick($now);
    if ($self->needs_recalc) {
        $self->recalc_stats;    
    }
    $self->add_happiness(sprintf('%.0f', $self->happiness_hour * $tick_rate));
    $self->add_waste(sprintf('%.0f', $self->waste_hour * $tick_rate));
    $self->add_energy(sprintf('%.0f', $self->energy_hour * $tick_rate));
    $self->add_water(sprintf('%.0f', $self->water_hour * $tick_rate));
    foreach my $type (ORE_TYPES) {
        my $hour_method = $type.'_hour';
        my $add_method = 'add_'.$type;
        $self->$add_method(sprintf('%.0f', $self->$hour_method() * $tick_rate));
    }
    my $food_consumed = sprintf('%.0f', $self->food_consumption_hour * $tick_rate);
    foreach my $type (shuffle FOOD_TYPES) {
        my $hour_method = $type.'_production_hour';
        my $add_method = 'add_'.$type;
        my $food_produced = sprintf('%.0f', $self->$hour_method() * $tick_rate);
        if ($food_produced > $food_consumed) {
            $food_produced -= $food_consumed;
            $food_consumed = 0;
            $self->$add_method($food_produced);
        }
        else {
            $food_consumed -= $food_produced;
        }
    }
    $self->update;
}

sub food_hour {
    my ($self) = @_;
    my $tally = 0;
    foreach my $food (FOOD_TYPES) {
        my $method = $food."_production_hour";
        $tally += $self->$method;
    }
    $tally -= $self->food_consumption_hour;
    return $tally;
}

sub food_stored {
    my ($self) = @_;
    my $tally = 0;
    foreach my $food (FOOD_TYPES) {
        my $method = $food."_stored";
        $tally += $self->$method;
    }
    return $tally;
}

sub ore_stored {
    my ($self) = @_;
    my $tally = 0;
    foreach my $ore (ORE_TYPES) {
        my $method = $ore."_stored";
        $tally += $self->$method;
    }
    return $tally;
}

sub add_ore {
    my ($self, $value) = @_;
    foreach my $type (shuffle ORE_TYPES) {
        next unless $self->$type >= 100; 
        my $add_method = 'add_'.$type;
        $self->$add_method($value);
        last;
    }
}

sub add_magnetite {
    my ($self, $value) = @_;
    my $amount_to_store = $self->magnetite_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->magnetite_stored;
    $self->magnetite_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_beryl {
    my ($self, $value) = @_;
    my $amount_to_store = $self->beryl_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->beryl_stored;
    $self->beryl_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_fluorite {
    my ($self, $value) = @_;
    my $amount_to_store = $self->fluorite_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->fluorite_stored;
    $self->fluorite_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_monazite {
    my ($self, $value) = @_;
    my $amount_to_store = $self->monazite_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->monazite_stored;
    $self->monazite_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_zircon {
    my ($self, $value) = @_;
    my $amount_to_store = $self->zircon_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->zircon_stored;
    $self->zircon_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_sulfur {
    my ($self, $value) = @_;
    my $amount_to_store = $self->sulfur_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->sulfur_stored;
    $self->sulfur_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_anthracite {
    my ($self, $value) = @_;
    my $amount_to_store = $self->anthracite_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->anthracite_stored;
    $self->anthracite_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_methane {
    my ($self, $value) = @_;
    my $amount_to_store = $self->methane_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->methane_stored;
    $self->methane_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_kerogen {
    my ($self, $value) = @_;
    my $amount_to_store = $self->kerogen_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->kerogen_stored;
    $self->kerogen_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_trona {
    my ($self, $value) = @_;
    my $amount_to_store = $self->trona_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->trona_stored;
    $self->trona_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_gypsum {
    my ($self, $value) = @_;
    my $amount_to_store = $self->gypsum_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->gypsum_stored;
    $self->gypsum_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_halite {
    my ($self, $value) = @_;
    my $amount_to_store = $self->halite_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->halite_stored;
    $self->halite_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_goethite {
    my ($self, $value) = @_;
    my $amount_to_store = $self->goethite_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->goethite_stored;
    $self->goethite_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_bauxite {
    my ($self, $value) = @_;
    my $amount_to_store = $self->bauxite_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->bauxite_stored;
    $self->bauxite_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_uraninite {
    my ($self, $value) = @_;
    my $amount_to_store = $self->uraninite_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->uraninite_stored;
    $self->uraninite_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_gold {
    my ($self, $value) = @_;
    my $amount_to_store = $self->gold_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->gold_stored;
    $self->gold_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_galena {
    my ($self, $value) = @_;
    my $amount_to_store = $self->galena_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->galena_stored;
    $self->galena_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_chalcopyrite {
    my ($self, $value) = @_;
    my $amount_to_store = $self->chalcopyrite_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->chalcopyrite_stored;
    $self->chalcopyrite_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_chromite {
    my ($self, $value) = @_;
    my $amount_to_store = $self->chromite_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->chromite_stored;
    $self->chromite_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_rutile {
    my ($self, $value) = @_;
    my $amount_to_store = $self->rutile_stored + $value;
    my $available_storage = $self->ore_capacity - $self->ore_stored + $self->rutile_stored;
    $self->rutile_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub spend_ore {
    my ($self, $value) = @_;
    my $subtract = sprintf('%.0f', $value / 5);
    SPEND: while (1) {
        foreach my $type (shuffle ORE_TYPES) {
            my $method = $type."_stored";
            my $stored = $self->$method;
            if ($stored > $subtract) {
                $self->$method($stored - $subtract);
                $value -= $subtract;
            }
            else {
                $value -= $stored;
                $self->$method(0);
            }
            last SPEND if ($value <= 0);
            $subtract = $value if ($subtract > $value);
        }
        last SPEND if ($subtract <= 0); # prevent an infinite loop scenario
    }
    return $self;
}

sub add_beetle {
    my ($self, $value) = @_;
    my $amount_to_store = $self->beetle_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->beetle_stored;
    $self->beetle_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_shake {
    my ($self, $value) = @_;
    my $amount_to_store = $self->shake_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->shake_stored;
    $self->shake_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_burger {
    my ($self, $value) = @_;
    my $amount_to_store = $self->burger_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->burger_stored;
    $self->burger_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_fungus {
    my ($self, $value) = @_;
    my $amount_to_store = $self->fungus_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->fungus_stored;
    $self->fungus_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_syrup {
    my ($self, $value) = @_;
    my $amount_to_store = $self->syrup_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->syrup_stored;
    $self->syrup_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_algae {
    my ($self, $value) = @_;
    my $amount_to_store = $self->algae_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->algae_stored;
    $self->algae_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_meal {
    my ($self, $value) = @_;
    my $amount_to_store = $self->meal_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->meal_stored;
    $self->meal_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_milk {
    my ($self, $value) = @_;
    my $amount_to_store = $self->milk_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->milk_stored;
    $self->milk_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_pancake {
    my ($self, $value) = @_;
    my $amount_to_store = $self->pancake_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->pancake_stored;
    $self->pancake_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_pie {
    my ($self, $value) = @_;
    my $amount_to_store = $self->pie_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->pie_stored;
    $self->pie_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_chip {
    my ($self, $value) = @_;
    my $amount_to_store = $self->chip_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->chip_stored;
    $self->chip_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_soup {
    my ($self, $value) = @_;
    my $amount_to_store = $self->soup_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->soup_stored;
    $self->soup_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_bread {
    my ($self, $value) = @_;
    my $amount_to_store = $self->bread_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->bread_stored;
    $self->bread_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_wheat {
    my ($self, $value) = @_;
    my $amount_to_store = $self->wheat_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->wheat_stored;
    $self->wheat_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_cider {
    my ($self, $value) = @_;
    my $amount_to_store = $self->cider_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->cider_stored;
    $self->cider_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_corn {
    my ($self, $value) = @_;
    my $amount_to_store = $self->corn_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->corn_stored;
    $self->corn_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_root {
    my ($self, $value) = @_;
    my $amount_to_store = $self->root_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->root_stored;
    $self->root_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_bean {
    my ($self, $value) = @_;
    my $amount_to_store = $self->bean_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->bean_stored;
    $self->bean_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_apple {
    my ($self, $value) = @_;
    my $amount_to_store = $self->apple_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->apple_stored;
    $self->apple_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_potato {
    my ($self, $value) = @_;
    my $amount_to_store = $self->potato_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->potato_stored;
    $self->potato_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub add_lapis {
    my ($self, $value) = @_;
    my $amount_to_store = $self->lapis_stored + $value;
    my $available_storage = $self->food_capacity - $self->food_stored + $self->lapis_stored;
    $self->lapis_stored( ($amount_to_store < $available_storage) ? $amount_to_store : $available_storage );
}

sub spend_food {
    my ($self, $value) = @_;
    my $subtract = sprintf('%.0f', $value / 5);
    SPEND: while (1) {
        foreach my $type (shuffle FOOD_TYPES) {
            my $method = $type."_stored";
            my $stored = $self->$method;
            if ($stored > $subtract) {
                $self->$method($stored - $subtract);
                $value -= $subtract;
            }
            else {
                $value -= $stored;
                $self->$method(0);
            }
            last SPEND if ($value <= 0);
            $subtract = $value if ($subtract > $value);
        }
        last SPEND if ($subtract <= 0); # prevent an infinite loop scenario
    }
    return $self;
}

sub add_energy {
    my ($self, $value) = @_;
    my $store = $self->energy_stored + $value;
    my $storage = $self->energy_capacity;
    $self->energy_stored( ($store < $storage) ? $store : $storage );
}

sub spend_energy {
    my ($self, $value) = @_;
    $self->energy_stored( $self->energy_stored - $value );
}

sub add_water {
    my ($self, $value) = @_;
    my $store = $self->water_stored + $value;
    my $storage = $self->water_capacity;
    $self->water_stored( ($store < $storage) ? $store : $storage );
}

sub spend_water {
    my ($self, $value) = @_;
    $self->water_stored( $self->water_stored - $value );
}

sub add_happiness {
    my ($self, $value) = @_;
    my $new = $self->happiness + $value;
    if ($new < 0 && $self->empire->is_isolationist) {
        $new = 0;
    }
    $self->happiness( $new );
    return $self;
}

sub spend_happiness {
    my ($self, $value) = @_;
    my $new = $self->happiness - $value;
    if ($new < 0 && $self->empire->is_isolationist) {
        $new = 0;
    }
    $self->happiness( $new );
    return $self;
}

sub add_waste {
    my ($self, $value) = @_;
    my $store = $self->waste_stored + $value;
    my $storage = $self->waste_capacity;
    if ($store < $storage) {
        $self->waste_stored( $store );
    }
    else {
        $self->waste_stored( $storage );
        $self->spend_happiness( $store - $storage ); # pollution
    }
}

sub spend_waste {
    my ($self, $value) = @_;
    $self->waste_stored( $self->waste_stored - $value );
}


no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
