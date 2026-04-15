<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $request->validate(['nik' => 'required', 'password' => 'required']);
        $user = User::where('nik', $request->nik)->first();

        $reqMobile = $request->mobileDeviceId;
        $reqDesktop = $request->desktopDeviceId;

        if ($user->role !== 'admin') {
             $device = $user->device;
             
             if ($device) {
                 if ($reqMobile) {
                      if ($device->mobileDeviceId && $device->mobileDeviceId !== $reqMobile) {
                          return response()->json(['message' => 'Perangkat Handphone Anda tidak dikenali. Silakan hubungi Admin melalui Pusat Bantuan untuk mereset perangkat.'], 403);
                      } else if (!$device->mobileDeviceId) {
                          $device->update(['mobileDeviceId' => $reqMobile]);
                      }
                 }
                 
                 if ($reqDesktop) {
                      if ($device->desktopDeviceId && $device->desktopDeviceId !== $reqDesktop) {
                          return response()->json(['message' => 'Perangkat Desktop (PC) Anda tidak dikenali. Silakan hubungi Admin melalui Pusat Bantuan untuk mereset perangkat.'], 403);
                      } else if (!$device->desktopDeviceId) {
                          $device->update(['desktopDeviceId' => $reqDesktop]);
                      }
                 }
             } else {
                 if ($reqMobile || $reqDesktop) {
                     $user->device()->create([
                         'id' => Str::uuid()->toString(),
                         'mobileDeviceId' => $reqMobile,
                         'desktopDeviceId' => $reqDesktop
                     ]);
                 }
             }
        }

        $token = $user->createToken('auth_token')->plainTextToken;
        return response()->json(['message' => 'Login berhasil', 'token' => $token, 'user' => $user->fresh()]);
    }

    public function register(Request $request)
    {
        $request->validate([
            'nik' => 'required|unique:users',
            'nama_lengkap' => 'required',
            'password' => 'required|min:6',
        ]);

        $user = User::create([
            'nik' => $request->nik,
            'nama_lengkap' => $request->nama_lengkap,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => $request->role ?? 'Karyawan',
            'area' => $request->area,
            'shift' => $request->shift ?? 'Pagi',
            'departemen_id' => $request->departemen_id,
            'jabatan' => $request->jabatan,
            'jenis_kelamin' => $request->jenis_kelamin,
            'tanggal_lahir' => $request->tanggal_lahir,
            'agama' => $request->agama,
            'alamat' => $request->alamat,
            'kontak' => $request->kontak,
        ]);

        if ($request->mobileDeviceId || $request->desktopDeviceId) {
             $user->device()->create([
                 'id' => Str::uuid()->toString(),
                 'mobileDeviceId' => $request->mobileDeviceId,
                 'desktopDeviceId' => $request->desktopDeviceId
             ]);
        }

        $token = $user->createToken('auth_token')->plainTextToken;
        return response()->json(['message' => 'Registrasi berhasil', 'token' => $token, 'user' => $user->fresh()], 201);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();
        return response()->json(['message' => 'Logout berhasil']);
    }

    public function profile(Request $request)
    {
        return response()->json(['user' => $request->user()]);
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();
        $user->update($request->only([
            'nama_lengkap', 'email', 'kontak', 'alamat', 'tanggal_lahir',
            'photo_base64', 'jenis_kelamin', 'area', 'shift', 'departemen_id', 'jabatan',
        ]));
        // If they update their device somehow? Assuming profile doesn't.
        return response()->json(['message' => 'Profil diperbarui', 'user' => $user->fresh()]);
    }

    public function changePassword(Request $request)
    {
        $request->validate([
            'current_password' => 'required',
            'new_password' => 'required|min:6',
        ]);

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json(['message' => 'Password lama salah'], 422);
        }

        $user->update(['password' => Hash::make($request->new_password)]);
        return response()->json(['message' => 'Password berhasil diubah']);
    }
}
