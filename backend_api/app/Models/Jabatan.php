<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;

class Jabatan extends Model
{
    use HasUuids;
    
    public $incrementing = false;
    protected $keyType = 'string';
    protected $fillable = ['id', 'departemen_id', 'nama_jabatan'];
}
