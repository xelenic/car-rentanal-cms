<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\View\View;

class CustomerController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:customers.view', only: ['index', 'show']),
            new Middleware('permission:customers.create', only: ['store']),
            new Middleware('permission:customers.update', only: ['update']),
            new Middleware('permission:customers.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $customers = Customer::query()
            ->withCount('hires')
            ->with(['hires' => fn ($query) => $query->with(['vehicle'])])
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate(10)
            ->withQueryString();

        return view('admin.customers.index', [
            'customers' => $customers,
            'search' => $request->string('search')->toString(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);

        $customer = Customer::create($data);

        return redirect()->route('admin.customers.index')->with('status', "Customer \"{$customer->name}\" was created.");
    }

    public function update(Request $request, Customer $customer): RedirectResponse
    {
        $data = $this->validated($request);

        $customer->update($data);

        return redirect()->route('admin.customers.index')->with('status', "Customer \"{$customer->name}\" was updated.");
    }

    public function destroy(Customer $customer): RedirectResponse
    {
        if ($customer->hires()->exists()) {
            return redirect()->route('admin.customers.index')->with('error', "Customer \"{$customer->name}\" has existing hires and cannot be deleted.");
        }

        $customer->delete();

        return redirect()->route('admin.customers.index')->with('status', "Customer \"{$customer->name}\" was deleted.");
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:30'],
            'email' => ['nullable', 'string', 'email', 'max:255'],
            'nic_passport' => ['nullable', 'string', 'max:100'],
            'address' => ['nullable', 'string'],
            'notes' => ['nullable', 'string'],
        ]);
    }
}
