package Lacuna::Role::Ship::Send::LoadSupplyPod;

use strict;
use Moose::Role;
use List::Util qw(shuffle);
use Lacuna::Util qw(randint);
use Lacuna::Constants qw(FOOD_TYPES ORE_TYPES);

requires 'supply_pod_level';

after send => sub {
   my $self = shift;
    my $part = $self->hold_size;
    my $food = $part;
    my $ore = $part;
    my $body = $self->body;
    my $payload;
    my $food_stored = 0;
    my $food_type_count = 0;
    for my $type (FOOD_TYPES) {
      my $stored = $body->type_stored($type);
      $food_stored += $stored;
      $food_type_count++ if ($stored);
    }
    foreach my $type (FOOD_TYPES) {
        my $stored = $body->type_stored($type);
        if ($stored) {
          my $amt = int(($food * $stored)/$food_stored);
          if ( $amt > 0 ) {
            $body->spend_type($type, $amt);
            $payload->{resources}{$type} = $amt;
          }
        }
    }
    my $ore_stored = 0;
    my $ore_type_count = 0;
    for my $type (ORE_TYPES) {
      my $stored = $body->type_stored($type);
      $ore_stored += $stored;
      $ore_type_count++ if ($stored);
    }
    foreach my $type (ORE_TYPES) {
        my $stored = $body->type_stored($type);
        if ($stored) {
          my $amt = int(($ore * $stored)/$ore_stored);
          if ( $amt > 0 ) {
            $body->spend_type($type, $amt);
            $payload->{resources}{$type} = $amt;
          }
        }
    }
    my $energy = $body->type_stored('energy');
    if ($energy >= $part) {
        $body->spend_type('energy', $part);
        $payload->{resources}{energy} = $part;
    }
    else {
        $body->spend_type('energy', $energy);
        $payload->{resources}{energy} = $energy if $energy;
    }
    my $water = $body->type_stored('water');
    if ($water >= $part) {
        $body->spend_type('water', $part);
        $payload->{resources}{water} = $part;
    }
    else {
        $body->spend_type('water', $water);
        $payload->{resources}{water} = $water if $water;
    }
    $self->payload($payload);
    $self->update;
    $body->update;
    Lacuna->cache->set('supply_pod_sent',$self->body_id,1,60*60*24);
};

after can_send_to_target => sub {
    my ($self, $target) = @_;
    confess [1010, 'Cannot send more than one per day per planet.']
      if (Lacuna->cache->get('supply_pod_sent',$self->body_id));
};

1;